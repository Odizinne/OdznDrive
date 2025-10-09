pragma Singleton
import QtQuick
import Odizinne.OdznDrive

QtObject {
    id: root

    property var checkedItems: ({})
    property int checkedCount: 0
    property string draggedItemPath: ""
    property string draggedItemName: ""
    property var currentDropTarget: null

    property real storagePercentage: 0.0
    property string storageOccupied: "--"
    property string storageTotal: "--"
    property bool anyDialogOpen: false

    property var navigationHistory: []
    property int navigationIndex: -1
    property bool isNavigating: false

    function getFileIcon(fileName) {
        if (!fileName || fileName === "")
            return "qrc:/icons/types/unknow.svg"

        const ext = fileName.split('.').pop().toLowerCase()

        const codeExt = ["c", "cpp", "cxx", "h", "hpp", "hxx", "cs", "java", "js", "ts", "py", "rb", "php", "go", "rs", "swift", "kt", "sh", "bat", "ps1", "html", "css", "scss"]
        const wordExt = ["doc", "docx", "odt", "rtf"]
        const excelExt = ["xls", "xlsx", "ods", "csv"]
        const pptExt = ["ppt", "pptx", "odp"]
        const pdfExt = ["pdf"]
        const textExt = ["txt", "md", "ini", "cfg", "json", "xml", "yml", "yaml", "log"]
        const picExt = ["png", "jpg", "jpeg", "gif", "bmp", "svg", "webp", "tif", "tiff"]
        const audioExt = ["mp3", "wav", "flac", "aac", "ogg", "m4a", "wma"]
        const videoExt = ["mp4", "avi", "mkv", "mov", "wmv", "flv", "webm"]
        const zipExt = ["zip", "rar", "7z", "tar", "gz", "bz2"]

        if (codeExt.indexOf(ext) !== -1) return "qrc:/icons/types/code.svg"
        if (wordExt.indexOf(ext) !== -1) return "qrc:/icons/types/word.svg"
        if (excelExt.indexOf(ext) !== -1) return "qrc:/icons/types/excel.svg"
        if (pptExt.indexOf(ext) !== -1) return "qrc:/icons/types/powerpoint.svg"
        if (pdfExt.indexOf(ext) !== -1) return "qrc:/icons/types/pdf.svg"
        if (textExt.indexOf(ext) !== -1) return "qrc:/icons/types/text.svg"
        if (picExt.indexOf(ext) !== -1) return "qrc:/icons/types/picture.svg"
        if (audioExt.indexOf(ext) !== -1) return "qrc:/icons/types/audio.svg"
        if (videoExt.indexOf(ext) !== -1) return "qrc:/icons/types/video.svg"
        if (zipExt.indexOf(ext) !== -1) return "qrc:/icons/types/zip.svg"

        return "qrc:/icons/types/unknow.svg"
    }

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

    // --- PATH & FORMATTING LOGIC ---

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

    function formatSizeFromKB(kilobytes) { // Corrected param name
        if (kilobytes < 1024) return kilobytes + " KB"
        if (kilobytes < 1024 * 1024) return Math.round(kilobytes / 1024) + " MB"
        if (kilobytes < 1024 * 1024 * 1024) return Math.round(kilobytes / 1024 / 1024) + " GB"
        return Math.round(kilobytes / 1024 / 1024 / 1024) + " TB"
    }

    function formatSizeFromMB(megabytes) {
        if (megabytes < 1024) return megabytes + " MB"
        if (megabytes < 1024 * 1024) return Math.round(megabytes / 1024) + " GB"
        if (megabytes < 1024 * 1024 * 1024) return Math.round(megabytes / 1024 / 1024) + " TB"
        return Math.round(megabytes / 1024 / 1024 / 1024) + " PB"
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

    function toNativeFilePath(path) {
        let pathStr = path.toString();
        if (pathStr.startsWith("file:")) {
            pathStr = pathStr.substring(5);
            while (pathStr.startsWith("/") || pathStr.startsWith("\\")) {
                pathStr = pathStr.substring(1);
            }
        }
        return pathStr;
    }


    function openFileDownloadDialog(remotePath, defaultName) {
        let cleanedFolderPath = toNativeFilePath(UserSettings.downloadFolderPath)
        FileDialogHelper.ensureDirectoryExists(cleanedFolderPath)
        let fullPath = FileDialogHelper.joinPath(cleanedFolderPath, defaultName)
        let localPath = toNativeFilePath(fullPath)
        ConnectionManager.downloadFile(remotePath, localPath)
    }

    function openFolderDownloadDialog(remotePath, defaultName) {
        let cleanedFolderPath = toNativeFilePath(UserSettings.downloadFolderPath)
        FileDialogHelper.ensureDirectoryExists(cleanedFolderPath)
        let fileName = defaultName.endsWith(".zip") ? defaultName : defaultName + ".zip"
        let fullPath = FileDialogHelper.joinPath(cleanedFolderPath, fileName)
        let localPath = toNativeFilePath(fullPath)
        ConnectionManager.downloadDirectory(remotePath, localPath)
    }

    function openMultiDownloadDialog(itemPaths) {
        let cleanedFolderPath = toNativeFilePath(UserSettings.downloadFolderPath)
        FileDialogHelper.ensureDirectoryExists(cleanedFolderPath)
        let defaultZipName = getMultiDownloadDefaultName()
        let fullPath = FileDialogHelper.joinPath(cleanedFolderPath, defaultZipName)
        let localPath = toNativeFilePath(fullPath)
        let fileName = localPath.split('/').pop().split('\\').pop()
        let zipName = fileName.endsWith('.zip') ? fileName.slice(0, -4) : fileName
        ConnectionManager.downloadMultiple(itemPaths, localPath, zipName)
        uncheckAll()
    }

    function getMultiDownloadDefaultName() {
        let now = new Date()
        let dateStr = Qt.formatDateTime(now, "yyyy-MM-dd_HH-mm-ss")
        return "OdznDrive_Download_" + dateStr + ".zip"
    }

    function pushToHistory(path) {
        if (isNavigating) {
            return
        }

        // If we're not at the end of history, remove everything after current position
        if (navigationIndex < navigationHistory.length - 1) {
            navigationHistory = navigationHistory.slice(0, navigationIndex + 1)
        }

        // Add new path if it's different from current
        if (navigationHistory.length === 0 || navigationHistory[navigationHistory.length - 1] !== path) {
            navigationHistory.push(path)
            navigationIndex = navigationHistory.length - 1

            // Limit history size to 50 entries
            if (navigationHistory.length > 50) {
                navigationHistory.shift()
                navigationIndex--
            }
        }
    }

    function canGoBack() {
        return navigationIndex > 0
    }

    function canGoForward() {
        return navigationIndex < navigationHistory.length - 1
    }

    function goBack() {
        if (canGoBack()) {
            navigationIndex--
            isNavigating = true
            ConnectionManager.listDirectory(navigationHistory[navigationIndex], UserSettings.foldersFirst)
        }
    }

    function goForward() {
        if (canGoForward()) {
            navigationIndex++
            isNavigating = true
            ConnectionManager.listDirectory(navigationHistory[navigationIndex], UserSettings.foldersFirst)
        }
    }

    function clearNavigationHistory() {
        navigationHistory = []
        navigationIndex = -1
        isNavigating = false
    }
}
