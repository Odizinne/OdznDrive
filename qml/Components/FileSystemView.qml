pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl

import QtQuick.Layouts
import Odizinne.OdznDrive

Page {
    id: root
    Material.background: "transparent"

    Binding {
        target: Utils
        property: "anyDialogOpen"
        value: renameDialog.visible ||
               newFolderDialog.visible ||
               deleteConfirmDialog.visible ||
               multiDeleteConfirmDialog.visible ||
               userAddDialog.visible ||
               userManagmentDialog.visible ||
               confirmDeleteUserDialog.visible
    }

    Connections {
        target: FileModel
        function onCurrentPathChanged() {
            Utils.uncheckAll()
        }
    }

    DragIndicator {
        id: dragIndicator
    }

    RenameDialog {
        id: renameDialog
        anchors.centerIn: parent
    }

    NewFolderDialog {
        id: newFolderDialog
        anchors.centerIn: parent
    }

    DeleteConfirmDialog {
        id: deleteConfirmDialog
        anchors.centerIn: parent
    }

    MultiDeleteConfirmDialog {
        id: multiDeleteConfirmDialog
        anchors.centerIn: parent
    }

    DropArea {
        id: dropArea
        anchors.fill: parent

        onEntered: (drag) => {
            if (drag.hasUrls && ConnectionManager.authenticated) {
                drag.accept(Qt.CopyAction)
                dropOverlay.visible = true
            }
        }

        onExited: {
            dropOverlay.visible = false
        }

        onDropped: (drop) => {
            dropOverlay.visible = false

            if (drop.hasUrls && ConnectionManager.authenticated) {
                let files = []
                for (let i = 0; i < drop.urls.length; i++) {
                    let fileUrl = drop.urls[i].toString()

                    let localPath = fileUrl
                    if (localPath.startsWith("file://")) {
                        localPath = localPath.substring(7)
                    }

                    if (localPath.match(/^\/[A-Za-z]:\//)) {
                        localPath = localPath.substring(1)
                    }

                    files.push(localPath)
                }

                if (files.length > 0) {
                    ConnectionManager.uploadFiles(files, FileModel.currentPath)
                }

                drop.accept(Qt.CopyAction)
            }
        }

        Rectangle {
            id: dropOverlay
            anchors.fill: parent
            color: Material.primary
            opacity: 0.2
            visible: false

            Label {
                anchors.centerIn: parent
                text: "Drop files here to upload"
                font.pixelSize: 24
                font.bold: true
                color: Material.primary
            }
        }
    }

    Label {
        anchors.centerIn: parent
        text: ConnectionManager.authenticated ?
                  (FileModel.count === 0 ? "Empty folder\n\nDrag files here to upload" :
                                           FilterProxyModel.rowCount() === 0 ? "No items match filter" : "") :
                  "Not connected"
        visible: ConnectionManager.authenticated ?
                     (FileModel.count === 0 || FilterProxyModel.rowCount() === 0) :
                     true
        opacity: 0.5
        font.pixelSize: 16
        horizontalAlignment: Text.AlignHCenter
    }

    EmptySpaceMenu {
        id: emptySpaceMenu
        onNewFolderClicked: newFolderDialog.open()
        onUploadFilesClicked: Utils.openUploadDialog()
        onRefreshClicked: ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: UserSettings.listView ? listViewComponent : tileViewComponent
        }
    }

    header: BreadcrumBar {
        id: breadcrumbBar
        Layout.margins: 12
        Layout.preferredHeight: 45
        Layout.fillWidth: true
        onRequestNewFolderDialog: newFolderDialog.open()
        onRequestMultiDeleteConfirmDialog: {
            multiDeleteConfirmDialog.itemCount = Utils.checkedCount
            multiDeleteConfirmDialog.open()
        }
    }

    footer: FooterBar {
        id: footerBar
        onShowUserManagmentDialog: userManagmentDialog.open()
    }

    ListModel {
        id: usersModel
        ListElement {
            name: "Test"
            maxStorage: 1200
            password: "1234"
            isAdmin: false
        }
        ListElement {
            name: "Test2"
            maxStorage: 2500
            password: "tomato"
            isAdmin: true
        }
        ListElement {
            name: "Test"
            maxStorage: 1200
            password: "dualshock"
            isAdmin: false
        }
    }

    CustomDialog {
        id: userAddDialog
        property bool editMode: false
        title: editMode ? "Edit user" : "Create user"
        standardButtons: Dialog.Close | Dialog.Ok
        anchors.centerIn: parent
        onClosed: {
            editMode = false
            nameField.text = ""
            passField.text = ""
            storageSpinbox.value = 1024
            adminCheckbox.checked = false
        }

        function openInEditMode(name, pass, storage, admin) {
            editMode = true
            nameField.text = name
            passField.text = pass
            storageSpinbox.value = storage
            adminCheckbox.checked = admin
            open()
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            RowLayout {
                Label {
                    text: "User name"
                    Layout.fillWidth: true
                }

                TextField {
                    id: nameField
                    placeholderText: "Jhon Smith"
                    Layout.preferredWidth: 180
                    Layout.preferredHeight: 35
                }
            }

            RowLayout {
                Label {
                    text: "User passsword"
                    Layout.fillWidth: true
                }

                TextField {
                    id: passField
                    placeholderText: "Password"
                    Layout.preferredWidth: 180
                    Layout.preferredHeight: 35
                }
            }

            RowLayout {
                Label {
                    text: "Storage (MB)"
                    Layout.fillWidth: true
                }

                SpinBox {
                    id: storageSpinbox
                    from: 100
                    to: 1024000
                    value: 1024
                    stepSize: 1024
                    editable: true
                    Layout.preferredHeight: 35
                }
            }

            RowLayout {
                Label {
                    text: "Is admin"
                    Layout.fillWidth: true
                }

                CheckBox {
                    id: adminCheckbox
                    checked: false
                }
            }
        }

        onAccepted: {
            if (!userAddDialog.editMode) {
                ConnectionManager.createNewUser(nameField.text.trim(), passField.text.trim(), storageSpinbox.value, adminCheckbox.checked)
            } else {
                ConnectionManager.editExistingUser(nameField.text.trim(), passField.text.trim(), storageSpinbox.value, adminCheckbox.checked)
            }
        }
    }

    CustomDialog {
        id: userManagmentDialog
        anchors.centerIn: parent
        height: 550
        width: 600
        standardButtons: Qt.Close
        ColumnLayout {
            id: mainLyt
            anchors.fill: parent
            spacing: 0

            RowLayout {
                Layout.bottomMargin: 10
                Label {
                    text: "User managment"
                    font.bold: true
                    font.pixelSize: 16
                    Layout.fillWidth: true
                }

                CustomButton {
                    icon.width: 16
                    icon.height: 16
                    icon.source: "qrc:/icons/new.svg"
                    onClicked: userAddDialog.open()
                }
            }

            Rectangle {
                Layout.bottomMargin: 10
                Layout.preferredHeight: 45
                Layout.fillWidth: true
                color: Constants.headerGradientStart
                radius: 4
                clip: true
                layer.enabled: true
                layer.effect: RoundedElevationEffect {
                    elevation: 6
                    roundedScale: 4
                }
                RowLayout {
                    height: 45
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.fill: parent
                    Label {
                        text: "Username"
                        Layout.fillWidth: true
                        Material.foreground: "black"
                        font.bold: true
                    }

                    Label {
                        text: "Storage"
                        Layout.maximumWidth: 80
                        Layout.minimumWidth: 80
                        Material.foreground: "black"
                        font.bold: true
                    }

                    Label {
                        text: "Admin"
                        Layout.maximumWidth: 70
                        Layout.minimumWidth: 70
                        Material.foreground: "black"
                        font.bold: true
                    }

                    Label {
                        text: "Actions"
                        Layout.maximumWidth: 70
                        Layout.minimumWidth: 70
                        Material.foreground: "black"
                        font.bold: true
                    }
                }
            }

            CustomScrollView {
                id: scrollView
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: userListView
                    width: scrollView.width
                    height: contentHeight
                    model: usersModel
                    headerPositioning: ListView.OverlayHeader
                    contentHeight: contentItem.childrenRect.height
                    contentWidth: width
                    clip: true
                    spacing: 5
                    interactive: false
                    delegate: Item {
                        id: userDel
                        width: userListView.width
                        height: 45
                        required property var model
                        required property int index
                        HoverHandler {
                            id: delHover
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: delHover.hovered ? Constants.borderColor : "transparent"
                            opacity: delHover.hovered ? 1 : 0
                            radius: 4
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        RowLayout {
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            anchors.fill: parent
                            Label {
                                text: userDel.model.name
                                Layout.fillWidth: true
                            }

                            Label {
                                text: Utils.formatSizeFromMB(userDel.model.maxStorage)
                                Layout.maximumWidth: 80
                                Layout.minimumWidth: 80
                            }

                            Item {
                                Layout.preferredHeight: 45
                                Layout.maximumWidth: 70
                                Layout.minimumWidth: 70
                                CheckBox {
                                    anchors.centerIn: parent
                                    checked: userDel.model.isAdmin
                                    enabled: false
                                    anchors.horizontalCenterOffset: -12
                                }
                            }

                            RowLayout {
                                Layout.maximumWidth: 70
                                Layout.minimumWidth: 70
                                opacity: delHover.hovered ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutQuad
                                    }
                                }

                                CustomButton {
                                    icon.width: 16
                                    icon.height: 16
                                    icon.source: "qrc:/icons/edit.svg"
                                    onClicked: userAddDialog.openInEditMode(userDel.model.name, userDel.model.password, userDel.model.maxStorage, userDel.model.isAdmin)
                                }

                                CustomButton {
                                    icon.width: 16
                                    icon.height: 16
                                    icon.source: "qrc:/icons/delete.svg"
                                    onClicked: {
                                        confirmDeleteUserDialog.username = userDel.model.name
                                        confirmDeleteUserDialog.open()
                                    }
                                }
                            }
                        }

                        Separator {
                            anchors.top: userDel.bottom
                            visible: userDel.index !== userListView.count
                            color: Constants.borderColor
                        }
                    }
                }
            }

            TextField {
                placeholderText: "Filter..."
                Layout.fillWidth: true
                Layout.preferredHeight: 35
            }
        }
    }

    CustomDialog {
        id: confirmDeleteUserDialog
        width: 300
        title: "Are you sure you want to delete " + confirmDeleteUserDialog.username + "?"
        property string username: ""
        standardButtons: Dialog.Cancel | Dialog.Yes

        Label {
            anchors.fill: parent
            text: "This action cannot be undone"
            wrapMode: Text.WordWrap
        }

        onAccepted: ConnectionManager.deleteUser(username)
    }

    Component {
        id: listViewComponent

        FileListView {
            //ContextMenu.menu: emptySpaceMenu
            onRequestRename: function(path, name) {
                renameDialog.itemPath = path
                renameDialog.itemName = name
                renameDialog.open()
            }

            onRequestDelete: function (path, isDir) {
                deleteConfirmDialog.itemPath = path
                deleteConfirmDialog.isDirectory = isDir
                deleteConfirmDialog.open()
            }

            onSetDragIndicatorX: function(x) {
                dragIndicator.x = x
            }

            onSetDragIndicatorY: function(y) {
                dragIndicator.y = y
            }

            onSetDragIndicatorVisible: function(visible) {
                dragIndicator.visible = visible
            }

            onSetDragIndicatorText: function (text) {
                dragIndicator.text = text
            }
            Component.onCompleted: setScrollViewMenu(emptySpaceMenu)
        }
    }

    Component {
        id: tileViewComponent

        FileTileView {
            ContextMenu.menu: emptySpaceMenu
            onRequestRename: function(path, name) {
                renameDialog.itemPath = path
                renameDialog.itemName = name
                renameDialog.open()
            }

            onRequestDelete: function (path, isDir) {
                deleteConfirmDialog.itemPath = path
                deleteConfirmDialog.isDirectory = isDir
                deleteConfirmDialog.open()
            }

            onSetDragIndicatorX: function(x) {
                dragIndicator.x = x
            }

            onSetDragIndicatorY: function(y) {
                dragIndicator.y = y
            }

            onSetDragIndicatorVisible: function(visible) {
                dragIndicator.visible = visible
            }

            onSetDragIndicatorText: function (text) {
                dragIndicator.text = text
            }
        }
    }
}
