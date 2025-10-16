import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import Odizinne.OdznDrive

CustomDialog {
    id: textPreviewDialog
    title: fileName
    width: 900
    height: 700
    parent: Overlay.overlay
    modal: true

    property string filePath: ""
    property string fileName: ""
    property string tempLocalPath: ""
    property bool isDownloading: false
    property bool isModified: false
    property bool isSaving: false
    property string originalContent: ""

    onAboutToShow: {
        isDownloading = true
        isModified = false
        isSaving = false
        textArea.text = ""
        originalContent = ""

        // Create temp file path
        tempLocalPath = FileDialogHelper.getTempFilePath(fileName)

        // Download file to temp location
        ConnectionManager.downloadFile(filePath, tempLocalPath)
    }

    onClosed: {
        // Clean up temp file
        if (tempLocalPath !== "") {
            FileDialogHelper.deleteFile(tempLocalPath)
            tempLocalPath = ""
        }
        textArea.text = ""
        originalContent = ""
        isModified = false
    }

    Connections {
        target: ConnectionManager

        function onDownloadComplete(path) {
            if (path === textPreviewDialog.tempLocalPath && textPreviewDialog.visible && textPreviewDialog.isDownloading) {
                // Read the downloaded file
                let content = FileDialogHelper.readTextFile(tempLocalPath)
                if (content !== null) {
                    textPreviewDialog.isDownloading = false
                    textArea.text = content
                    textPreviewDialog.originalContent = content
                    textPreviewDialog.isModified = false
                } else {
                    textPreviewDialog.isDownloading = false
                    // Show error
                }
            }
        }

        function onUploadComplete(path) {
            if (path === textPreviewDialog.filePath && textPreviewDialog.isSaving) {
                textPreviewDialog.isSaving = false
                textPreviewDialog.originalContent = textArea.text
                textPreviewDialog.isModified = false
                // Refresh the directory listing
                ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
            }
        }

        function onErrorOccurred(error) {
            if (textPreviewDialog.isDownloading || textPreviewDialog.isSaving) {
                textPreviewDialog.isDownloading = false
                textPreviewDialog.isSaving = false
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent

        BusyIndicator {
            visible: textPreviewDialog.isDownloading || textPreviewDialog.isSaving
            running: textPreviewDialog.isDownloading || textPreviewDialog.isSaving
            Material.accent: Constants.headerGradientStart
        }

        Label {
            text: textPreviewDialog.isSaving ? "Saving..." : "Loading..."
            visible: textPreviewDialog.isDownloading || textPreviewDialog.isSaving
            opacity: 0.7
        }

        ScrollView {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !textPreviewDialog.isDownloading && !textPreviewDialog.isSaving
            clip: true
            ScrollBar.vertical: ScrollBar {
                id: vBar
                parent: scrollView
                anchors.right: scrollView.right
                anchors.top: scrollView.top
                anchors.bottom: scrollView.bottom

                policy: scrollView.contentHeight > scrollView.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff

                contentItem: Rectangle {
                    implicitWidth: vBar.interactive ? 10 : 4
                    implicitHeight: vBar.interactive ? 10 : 4
                    radius: 4
                    color: vBar.pressed ? Constants.scrollBarColor :
                           vBar.interactive && vBar.hovered ? Constants.scrollBarPressedColor :
                           Constants.scrollBarHoveredColor
                    opacity: 1

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }

                    Behavior on implicitWidth {
                        NumberAnimation { duration: 100 }
                    }
                }

                background: Item {}
            }

            TextArea {
                id: textArea
                wrapMode: TextArea.Wrap
                selectByMouse: true
                font.family: "Consolas, Monaco, Courier New, monospace"
                font.pixelSize: 13

                onTextChanged: {
                    if (!textPreviewDialog.isDownloading && textArea.text !== textPreviewDialog.originalContent) {
                        textPreviewDialog.isModified = true
                    }
                }
            }
        }
    }

    footer: DialogButtonBox {
        CustomButton {
            flat: true
            text: "Save"
            enabled: textPreviewDialog.isModified && !textPreviewDialog.isSaving
            visible: !textPreviewDialog.isDownloading
            onClicked: {
                // Write text to temp file
                if (FileDialogHelper.writeTextFile(textPreviewDialog.tempLocalPath, textArea.text)) {
                    textPreviewDialog.isSaving = true
                    // Upload the temp file back to server
                    ConnectionManager.uploadFile(textPreviewDialog.tempLocalPath, textPreviewDialog.filePath)
                }
            }
        }

        CustomButton {
            flat: true
            text: "Close"
            onClicked: {
                if (textPreviewDialog.isModified) {
                    unsavedChangesDialog.open()
                } else {
                    textPreviewDialog.close()
                }
            }
        }
    }

    CustomDialog {
        id: unsavedChangesDialog
        title: "Unsaved Changes"
        parent: Overlay.overlay
        anchors.centerIn: parent

        ColumnLayout {
            anchors.fill: parent
            spacing: 15

            Label {
                text: "You have unsaved changes. Do you want to save before closing?"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        footer: DialogButtonBox {
            CustomButton {
                flat: true
                text: "Discard"
                onClicked: {
                    unsavedChangesDialog.close()
                    textPreviewDialog.close()
                }
            }

            CustomButton {
                flat: true
                text: "Cancel"
                onClicked: unsavedChangesDialog.close()
            }

            CustomButton {
                flat: true
                text: "Save"
                onClicked: {
                    unsavedChangesDialog.close()
                    // Write and upload
                    if (FileDialogHelper.writeTextFile(textPreviewDialog.tempLocalPath, textArea.text)) {
                        textPreviewDialog.isSaving = true
                        ConnectionManager.uploadFile(textPreviewDialog.tempLocalPath, textPreviewDialog.filePath)
                    }
                    // Close after upload completes
                    Qt.callLater(function() {
                        textPreviewDialog.close()
                    })
                }
            }
        }
    }
}
