pragma Singleton
import QtQuick

QtObject {
    signal requestShowDeleteConfirm(string path, bool isDir)
    signal requestShowDownloadDialog(string remotePath)
}
