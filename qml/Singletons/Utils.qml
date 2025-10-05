pragma Singleton
import QtQuick
import Odizinne.OdznDrive

QtObject {
    property var checkedItems: ({})
    property int checkedCount: 0
    property string draggedItemPath: ""
    property string draggedItemName: ""
    property var currentDropTarget: null

    property real storagePercentage: 0.0
    property string storageOccupied: "--"
    property string storageTotal: "--"
    signal requestSettingsDialog()

    function isItemChecked(path) {
        return checkedItems[path] === true
    }

    function toggleItemChecked(path) {
        let newChecked = Object.assign({}, checkedItems)
        if (newChecked[path]) {
            delete newChecked[path]
        } else {
            newChecked[path] = true
        }
        checkedItems = newChecked
        updateCheckedCount()
    }

    function checkAll() {
        let newChecked = {}
        for (let i = 0; i < FilterProxyModel.rowCount(); i++) {
            let item = FilterProxyModel.data(FilterProxyModel.index(i, 0), 258) // PathRole
            newChecked[item] = true
        }
        checkedItems = newChecked
        updateCheckedCount()
    }

    function uncheckAll() {
        checkedItems = {}
        updateCheckedCount()
    }

    function updateCheckedCount() {
        let count = 0
        for (let key in checkedItems) {
            if (checkedItems[key]) {
                count++
            }
        }
        checkedCount = count
    }

    function getCheckedPaths() {
        let paths = []
        for (let key in checkedItems) {
            if (checkedItems[key]) {
                paths.push(key)
            }
        }
        return paths
    }

    function getCheckedItems() {
        let items = []
        for (let i = 0; i < FilterProxyModel.rowCount(); i++) {
            let idx = FilterProxyModel.index(i, 0)
            let path = FilterProxyModel.data(idx, 258) // PathRole
            if (isItemChecked(path)) {
                items.push({
                               path: path,
                               name: FilterProxyModel.data(idx, 257), // NameRole
                               isDir: FilterProxyModel.data(idx, 259) // IsDirRole
                           })
            }
        }
        return items
    }

    function getPathSegments() {
        if (!FileModel.currentPath || FileModel.currentPath === "" || FileModel.currentPath === "/") {
            return []
        }

        let path = FileModel.currentPath
        if (path.startsWith("/")) {
            path = path.substring(1)
        }
        if (path.endsWith("/")) {
            path = path.substring(0, path.length - 1)
        }

        return path.split("/")
    }

    function getPathUpToIndex(index) {
        let segments = getPathSegments()
        let pathParts = segments.slice(0, index + 1)
        return pathParts.join("/")
    }

    function getHiddenSegments() {
        let segments = getPathSegments()
        if (segments.length <= 1) {
            return []
        }
        return segments.slice(0, -1)
    }

    function getPathUpToHiddenIndex(index) {
        let segments = getPathSegments()
        let pathParts = segments.slice(0, index + 1)
        return pathParts.join("/")
    }

    function getLastSegment() {
        let segments = getPathSegments()
        if (segments.length === 0) {
            return ""
        }
        return segments[segments.length - 1]
    }

    function formatSize(bytes) {
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1024 * 1024) return Math.round(bytes / 1024) + " KB"
        if (bytes < 1024 * 1024 * 1024) return Math.round(bytes / 1024 / 1024) + " MB"
        return Math.round(bytes / 1024 / 1024 / 1024) + " GB"
    }

    function formatDate(dateString) {
        let date = new Date(dateString)
        return date.toLocaleString(Qt.locale(), "yyyy-MM-dd HH:mm")
    }

    function formatStorage(bytes) {
        let mb = bytes / (1024 * 1024)
        if (mb >= 1000) {
            let gb = mb / 1024
            return gb.toFixed(1) + " GB"
        }
        return Math.round(mb) + " MB"
    }

    function openUploadDialog() {
        let files = FileDialogHelper.openFiles("Select Files to Upload")
        if (files.length > 0) {
            ConnectionManager.uploadFiles(files, FileModel.currentPath)
        }
    }

    function openFileDownloadDialog(remotePath, defaultName) {
        let localPath = FileDialogHelper.saveFile("Save File", defaultName, "")
        if (localPath !== "") {
            ConnectionManager.downloadFile(remotePath, localPath)
        }
    }

    function openFolderDownloadDialog(remotePath, defaultName) {
        let localPath = FileDialogHelper.saveFile("Save Folder as Zip", defaultName, "Zip files (*.zip)")
        if (localPath !== "") {
            if (!localPath.endsWith(".zip")) {
                localPath += ".zip"
            }
            ConnectionManager.downloadDirectory(remotePath, localPath)
        }
    }

    function openMultiDownloadDialog(itemPaths) {
        let localPath = FileDialogHelper.saveFile("Save as Zip", getMultiDownloadDefaultName(), "Zip files (*.zip)")
        if (localPath !== "") {
            if (!localPath.endsWith(".zip")) {
                localPath += ".zip"
            }

            let fileName = localPath.split('/').pop().split('\\').pop()
            let zipName = fileName.endsWith('.zip') ? fileName.slice(0, -4) : fileName

            ConnectionManager.downloadMultiple(itemPaths, localPath, zipName)
            uncheckAll()
        }
    }

    function getMultiDownloadDefaultName() {
        let now = new Date()
        let dateStr = Qt.formatDateTime(now, "yyyy-MM-dd_HH-mm-ss")
        return "OdznDrive_Download_" + dateStr + ".zip"
    }
}
