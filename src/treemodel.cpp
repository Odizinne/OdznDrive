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
    qDebug() << "Loading tree with data:" << treeData;

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

    qDebug() << "Root node:" << m_rootNode->name << "path:" << m_rootNode->path;

    QVariantList childrenList = treeData["children"].toList();
    qDebug() << "Children count:" << childrenList.size();

    for (const QVariant &childData : childrenList) {
        buildTree(m_rootNode, childData.toMap());
    }

    // Build visible nodes list
    rebuildVisibleNodes();

    qDebug() << "Total visible nodes:" << m_visibleNodes.count();

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

    qDebug() << "Built node:" << node->name << "under parent:" << parent->name;

    QVariantList childrenList = data["children"].toList();
    for (const QVariant &childData : childrenList) {
        buildTree(node, childData.toMap());
    }
}

void TreeModel::toggleExpanded(const QString &path)
{
    qDebug() << "Toggling expansion for path:" << path;

    TreeNode *node = findNode(m_rootNode, path);
    if (!node) {
        qDebug() << "Node not found for path:" << path;
        return;
    }

    node->isExpanded = !node->isExpanded;

    qDebug() << "Node" << node->name << "expanded:" << node->isExpanded;

    // Rebuild visible nodes list
    beginResetModel();
    m_visibleNodes.clear();
    rebuildVisibleNodes();
    endResetModel();

    qDebug() << "Visible nodes after toggle:" << m_visibleNodes.count();
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

    for (TreeNode *child : node->children) {
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

    // Helper lambda to recursively add visible nodes
    std::function<void(TreeNode*)> addVisibleNodes = [&](TreeNode* node) {
        if (!node) {
            return;
        }

        m_visibleNodes.append(node);

        if (node->isExpanded) {
            for (TreeNode* child : node->children) {
                addVisibleNodes(child);
            }
        }
    };

    addVisibleNodes(m_rootNode);
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
