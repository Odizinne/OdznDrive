#ifndef FILTERPROXYMODEL_H
#define FILTERPROXYMODEL_H

#include <QSortFilterProxyModel>
#include <qqml.h>

class FilterProxyModel : public QSortFilterProxyModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString filterText READ filterText WRITE setFilterText NOTIFY filterTextChanged)

public:
    static FilterProxyModel* create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);
    static FilterProxyModel* instance();

    QString filterText() const { return m_filterText; }
    void setFilterText(const QString &text);

signals:
    void filterTextChanged();

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;

private:
    explicit FilterProxyModel(QObject *parent = nullptr);
    FilterProxyModel(const FilterProxyModel&) = delete;
    FilterProxyModel& operator=(const FilterProxyModel&) = delete;

    static FilterProxyModel *s_instance;

    QString m_filterText;
    bool isWildcardPattern(const QString &text) const;
    bool matchesWildcard(const QString &fileName, const QString &pattern) const;
};

#endif // FILTERPROXYMODEL_H
