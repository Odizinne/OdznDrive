import QtQuick.Controls.Material
import QtQuick
import Odizinne.OdznDrive
import QtQuick.Layouts

CustomDialog {
    id: userAddDialog
    property bool editMode: false
    title: editMode ? "Edit user" : "Create user"
    property string originalName: ""
    anchors.centerIn: parent
    onClosed: {
        editMode = false
        originalName = ""
        nameField.text = ""
        passField.text = ""
        storageSpinbox.value = 1024
        adminCheckbox.checked = false
        errorText.visible = false
    }

    function openInEditMode(name, pass, storage, admin) {
        editMode = true
        originalName = name
        nameField.text = name
        passField.text = pass
        storageSpinbox.value = storage
        adminCheckbox.checked = admin
        open()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Label {
            id: errorText
            Layout.fillWidth: true
            Material.foreground: Material.Red
            visible: false
            wrapMode: Text.WordWrap
        }

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

    footer: DialogButtonBox {
        Button {
            flat: true
            text: "Cancel"
            onClicked: userAddDialog.close()
        }

        Button {
            flat: true
            highlighted: true
            text: userAddDialog.editMode ? "Save Changes" : "Create User"
            onClicked: {
                errorText.visible = false;
                errorText.text = "";

                const username = nameField.text.trim();
                const password = passField.text.trim();

                if (username === "") {
                    errorText.text = "Username cannot be empty.";
                    errorText.visible = true;
                    return;
                }
                if (password === "" && !userAddDialog.editMode) {
                    errorText.text = "Password cannot be empty for a new user.";
                    errorText.visible = true;
                    return;
                }

                const existingUserIndex = UserModel.findUserIndex(username);

                if (existingUserIndex !== -1) {
                    if (!userAddDialog.editMode) {
                        errorText.text = "A user with this username already exists.";
                        errorText.visible = true;
                        return;
                    }
                    if (userAddDialog.editMode && username !== userAddDialog.originalName) {
                        errorText.text = "A user with this username already exists.";
                        errorText.visible = true;
                        return;
                    }
                }

                if (!userAddDialog.editMode) {
                    ConnectionManager.createNewUser(username, password, storageSpinbox.value, adminCheckbox.checked);
                } else {
                    ConnectionManager.editExistingUser(username, password, storageSpinbox.value, adminCheckbox.checked);
                }

                userAddDialog.close();
            }
        }
    }
}
