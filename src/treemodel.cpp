#include "treemodel.h"
#include <QDebug>

TreeModel* TreeModel::s_instance = nullptr;

TreeModel::TreeModel(QObject *parent)
    : QAbstractItemModel(parent)
    , m_rootNode(nullptr)
{
}

TreeModel* TreeModel::create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
{
    Q_UNUSED(qmlEngine)
    Q_UNUSED(jsEngine)
    return instance();
}

TreeModel* TreeModel::instance()
{
    if (!s_instance) {
        s_instance = new TreeModel();
    }
    return s_instance;
}

QModelIndex TreeModel::index(int row, int column, const QModelIndex &parent) const
{
    Q_UNUSED(parent)

    if (row < 0 || row >= m_visibleNodes.count() || column != 0) {
        return QModelIndex();
    }

    return createIndex(row, column, m_visibleNodes.at(row));
}

QModelIndex TreeModel::parent(const QModelIndex &child) const
{
    Q_UNUSED(child)
    return QModelIndex();
}

int TreeModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }

    return m_visibleNodes.count();
}

int TreeModel::columnCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent)
    return 1;
}

QVariant TreeModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_visibleNodes.count()) {
        return QVariant();
    }

    TreeNode *node = m_visibleNodes.at(index.row());
    if (!node) {
        return QVariant();
    }

    switch (role) {
    case NameRole:
        return node->name;
    case PathRole:
        return node->path;
    case IsExpandedRole:
        return node->isExpanded;
    case HasChildrenRole:
        return node->hasChildren;
    case DepthRole:
        return calculateDepth(node);
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> TreeModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[NameRole] = "name";
    roles[PathRole] = "path";
    roles[IsExpandedRole] = "isExpanded";
    roles[HasChildrenRole] = "hasChildren";
    roles[DepthRole] = "depth";
    return roles;
}

void TreeModel::loadTree(const QVariantMap &treeData)
{
    beginResetModel();

    if (m_rootNode) {
        delete m_rootNode;
        m_rootNode = nullptr;
    }
    m_visibleNodes.clear();

    m_rootNode = new TreeNode();
    m_rootNode->name = treeData["name"].toString();
    m_rootNode->path = treeData["path"].toString();
    m_rootNode->hasChildren = treeData["hasChildren"].toBool();

    QVariantList childrenList = treeData["children"].toList();

    for (const QVariant &childData : std::as_const(childrenList)) {
        buildTree(m_rootNode, childData.toMap());
    }

    rebuildVisibleNodes();
    endResetModel();
}

void TreeModel::buildTree(TreeNode *parent, const QVariantMap &data)
{
    TreeNode *node = new TreeNode();
    node->name = data["name"].toString();
    node->path = data["path"].toString();
    node->hasChildren = data["hasChildren"].toBool();
    node->parent = parent;

    parent->children.append(node);

    QVariantList childrenList = data["children"].toList();
    for (const QVariant &childData : std::as_const(childrenList)) {
        buildTree(node, childData.toMap());
    }
}

void TreeModel::toggleExpanded(const QString &path)
{
    TreeNode *node = findNode(m_rootNode, path);
    if (!node) {
        return;
    }

    int nodeIndex = m_visibleNodes.indexOf(node);
    if (nodeIndex < 0) {
        return;
    }

    node->isExpanded = !node->isExpanded;

    if (node->isExpanded) {
        if (!node->children.isEmpty()) {
            int insertCount = countVisibleDescendants(node);

            if (insertCount > 0) {
                beginInsertRows(QModelIndex(), nodeIndex + 1, nodeIndex + insertCount);

                QList<TreeNode*> childNodes;
                collectVisibleNodes(node, childNodes);

                for (int i = 0; i < childNodes.count(); ++i) {
                    m_visibleNodes.insert(nodeIndex + 1 + i, childNodes[i]);
                }

                endInsertRows();
            }
        }
    } else {
        int removeCount = countVisibleDescendants(node);

        if (removeCount > 0) {
            beginRemoveRows(QModelIndex(), nodeIndex + 1, nodeIndex + removeCount);

            for (int i = 0; i < removeCount; ++i) {
                m_visibleNodes.removeAt(nodeIndex + 1);
            }

            endRemoveRows();
        }
    }

    QModelIndex nodeModelIndex = index(nodeIndex, 0);
    emit dataChanged(nodeModelIndex, nodeModelIndex, {IsExpandedRole});
}

void TreeModel::clear()
{
    beginResetModel();
    if (m_rootNode) {
        delete m_rootNode;
        m_rootNode = nullptr;
    }
    m_visibleNodes.clear();
    endResetModel();
}

TreeNode* TreeModel::nodeFromIndex(const QModelIndex &index) const
{
    if (!index.isValid() || index.row() >= m_visibleNodes.count()) {
        return nullptr;
    }
    return m_visibleNodes.at(index.row());
}

TreeNode* TreeModel::findNode(TreeNode *node, const QString &path) const
{
    if (!node) {
        return nullptr;
    }

    if (node->path == path) {
        return node;
    }

    for (TreeNode *child : std::as_const(node->children)) {
        TreeNode *found = findNode(child, path);
        if (found) {
            return found;
        }
    }

    return nullptr;
}

void TreeModel::rebuildVisibleNodes()
{
    m_visibleNodes.clear();

    if (!m_rootNode) {
        return;
    }

    std::function<void(TreeNode*)> addVisibleNodes = [&](TreeNode* node) {
        if (!node) {
            return;
        }

        m_visibleNodes.append(node);

        if (node->isExpanded) {
            for (TreeNode* child : std::as_const(node->children)) {
                addVisibleNodes(child);
            }
        }
    };

    addVisibleNodes(m_rootNode);
}

int TreeModel::countVisibleDescendants(TreeNode* node) const
{
    int count = 0;

    for (TreeNode* child : std::as_const(node->children)) {
        count++;

        if (child->isExpanded && child->hasChildren) {
            count += countVisibleDescendants(child);
        }
    }

    return count;
}

void TreeModel::collectVisibleNodes(TreeNode* node, QList<TreeNode*>& result)
{
    for (TreeNode* child : std::as_const(node->children)) {
        result.append(child);

        if (child->isExpanded && child->hasChildren) {
            collectVisibleNodes(child, result);
        }
    }
}

int TreeModel::calculateDepth(const TreeNode *node) const
{
    int depth = 0;
    const TreeNode *current = node;
    while (current && current->parent) {
        depth++;
        current = current->parent;
    }
    return depth;
}

int TreeModel::getMaxDepth() const
{
    if (!m_rootNode) {
        return 0;
    }
    return calculateMaxDepth(m_rootNode);
}

int TreeModel::calculateMaxDepth(const TreeNode* node) const
{
    if (!node || !node->isExpanded || node->children.isEmpty()) {
        return 0;
    }

    int maxChildDepth = 0;
    for (const TreeNode* child : node->children) {
        int childDepth = calculateMaxDepth(child);
        maxChildDepth = qMax(maxChildDepth, childDepth);
    }

    return maxChildDepth + 1;
}

QStringList TreeModel::getExpandedPaths() const
{
    QStringList paths;
    if (m_rootNode) {
        collectExpandedPaths(m_rootNode, paths);
    }
    return paths;
}

void TreeModel::collectExpandedPaths(TreeNode* node, QStringList& paths) const
{
    if (!node) {
        return;
    }

    if (node->isExpanded) {
        paths.append(node->path);
        for (TreeNode* child : std::as_const(node->children)) {
            collectExpandedPaths(child, paths);
        }
    }
}

void TreeModel::restoreExpandedPaths(const QStringList &paths)
{
    for (const QString &path : paths) {
        TreeNode* node = findNode(m_rootNode, path);
        if (node && !node->isExpanded) {
            toggleExpanded(path);
        }
    }
}
