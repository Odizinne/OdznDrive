#include "filterproxymodel.h"
#include "filemodel.h"
#include <QRegularExpression>

FilterProxyModel* FilterProxyModel::s_instance = nullptr;

FilterProxyModel::FilterProxyModel(QObject *parent)
    : QSortFilterProxyModel(parent)
{
    setSourceModel(FileModel::instance());
    setFilterRole(FileModel::NameRole);
    setFilterCaseSensitivity(Qt::CaseInsensitive);
}

FilterProxyModel* FilterProxyModel::create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
{
    Q_UNUSED(qmlEngine)
    Q_UNUSED(jsEngine)

    return instance();
}

FilterProxyModel* FilterProxyModel::instance()
{
    if (!s_instance) {
        s_instance = new FilterProxyModel();
    }
    return s_instance;
}

void FilterProxyModel::setFilterText(const QString &text)
{
    if (m_filterText != text) {
        m_filterText = text.trimmed();
        emit filterTextChanged();
        invalidateFilter();
    }
}

bool FilterProxyModel::isWildcardPattern(const QString &text) const
{
    return text.contains('*') || text.contains('?');
}

bool FilterProxyModel::matchesWildcard(const QString &fileName, const QString &pattern) const
{
    QString regexPattern = QRegularExpression::escape(pattern);
    regexPattern.replace("\\*", ".*");
    regexPattern.replace("\\?", ".");

    QRegularExpression regex("^" + regexPattern + "$", QRegularExpression::CaseInsensitiveOption);
    return regex.match(fileName).hasMatch();
}

bool FilterProxyModel::filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const
{
    if (m_filterText.isEmpty()) {
        return true;
    }

    QModelIndex index = sourceModel()->index(sourceRow, 0, sourceParent);
    QString fileName = sourceModel()->data(index, FileModel::NameRole).toString();

    if (isWildcardPattern(m_filterText)) {
        return matchesWildcard(fileName, m_filterText);
    } else {
        return fileName.contains(m_filterText, Qt::CaseInsensitive);
    }
}
