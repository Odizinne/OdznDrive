#ifndef TREEMODEL_H
#define TREEMODEL_H

#include <QAbstractItemModel>
#include <QJsonObject>
#include <qqml.h>

struct TreeNode {
    QString name;
    QString path;
    bool isExpanded = false;
    bool hasChildren = false;
    QList<TreeNode*> children;
    TreeNode* parent = nullptr;

    ~TreeNode() {
        qDeleteAll(children);
    }
};

class TreeModel : public QAbstractItemModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        PathRole,
        IsExpandedRole,
        HasChildrenRole,
        DepthRole
    };

    static TreeModel* create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);
    static TreeModel* instance();

    QModelIndex index(int row, int column, const QModelIndex &parent = QModelIndex()) const override;
    QModelIndex parent(const QModelIndex &child) const override;
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int columnCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void loadTree(const QVariantMap &treeData);
    Q_INVOKABLE void toggleExpanded(const QString &path);
    Q_INVOKABLE void clear();
    Q_INVOKABLE int getMaxDepth() const;
    Q_INVOKABLE QStringList getExpandedPaths() const;
    Q_INVOKABLE void restoreExpandedPaths(const QStringList &paths);

private:
    explicit TreeModel(QObject *parent = nullptr);
    TreeModel(const TreeModel&) = delete;
    TreeModel& operator=(const TreeModel&) = delete;

    TreeNode* nodeFromIndex(const QModelIndex &index) const;
    TreeNode* findNode(TreeNode* node, const QString &path) const;
    void buildTree(TreeNode* parent, const QVariantMap &data);
    int calculateDepth(const TreeNode* node) const;
    void rebuildVisibleNodes();
    int countVisibleDescendants(TreeNode* node) const;
    void collectVisibleNodes(TreeNode* node, QList<TreeNode*>& result);
    int calculateMaxDepth(const TreeNode* node) const;
    void collectExpandedPaths(TreeNode* node, QStringList& paths) const;

    static TreeModel *s_instance;
    TreeNode *m_rootNode;
    QList<TreeNode*> m_visibleNodes;
};

#endif // TREEMODEL_H
