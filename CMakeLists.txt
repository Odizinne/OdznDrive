cmake_minimum_required(VERSION 3.21)

project(OdznDrive VERSION 0.10.2 LANGUAGES CXX)

set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install" CACHE PATH "Installation directory" FORCE)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTORCC ON)
set(QT_QML_GENERATE_QMLLS_INI ON)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick Network WebSockets Widgets)

qt_standard_project_setup(REQUIRES 6.8)

set(SOURCES
    src/main.cpp
    src/connectionmanager.cpp
    src/filemodel.cpp
    src/imagepreviewprovider.cpp
    src/filterproxymodel.cpp
    src/filedialoghelper.cpp
    src/windowsplatform.cpp
    src/usermodel.cpp
)

set(HEADERS
    include/connectionmanager.h
    include/filemodel.h
    include/imagepreviewprovider.h
    include/filterproxymodel.h
    include/filedialoghelper.h
    include/windowsplatform.h
    include/usermodel.h
)

set(QML_FILES
    qml/Main.qml

    qml/Components/BreadcrumBar.qml
    qml/Components/DragIndicator.qml
    qml/Components/EmptySpaceMenu.qml
    qml/Components/FileListView.qml
    qml/Components/FileSystemView.qml
    qml/Components/FileTileView.qml
    qml/Components/FooterBar.qml
    qml/Components/ItemContextMenu.qml
    qml/Components/Separator.qml
    qml/Components/LoginPage.qml
    qml/Components/LoginArt.qml

    qml/CustomComponents/CustomButton.qml
    qml/CustomComponents/CustomDialog.qml
    qml/CustomComponents/CustomMenu.qml
    qml/CustomComponents/CustomProgressBar.qml
    qml/CustomComponents/CustomScrollView.qml
    qml/CustomComponents/CustomBusyIndicator.qml
    qml/CustomComponents/CustomStackView.qml

    qml/Dialogs/DeleteConfirmDialog.qml
    qml/Dialogs/DownloadProgressDialog.qml
    qml/Dialogs/ErrorDialog.qml
    qml/Dialogs/MultiDeleteConfirmDialog.qml
    qml/Dialogs/NewFolderDialog.qml
    qml/Dialogs/RenameDialog.qml
    qml/Dialogs/UploadProgressDialog.qml
    qml/Dialogs/UserAddDialog.qml
    qml/Dialogs/UserManagmentDialog.qml
    qml/Dialogs/ConfirmDeleteUserDialog.qml
)


set(QML_SINGLETONS
    qml/Singletons/UserSettings.qml
    qml/Singletons/Constants.qml
    qml/Singletons/Utils.qml
)

# Get git commit hash
find_package(Git QUIET)
if(GIT_FOUND AND EXISTS "${PROJECT_SOURCE_DIR}/.git")
    execute_process(
        COMMAND ${GIT_EXECUTABLE} rev-parse --short HEAD
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_COMMIT_HASH
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
else()
    set(GIT_COMMIT_HASH "unknown")
endif()

string(TIMESTAMP BUILD_TIMESTAMP "%Y-%m-%d %H:%M:%S UTC" UTC)

# Generate version header
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/src/version.h.in"
    "${CMAKE_CURRENT_BINARY_DIR}/version.h"
)

# Windows-specific configuration
if(WIN32)
    # Configure Windows metadata
    set(APP_ICON_PATH "${CMAKE_CURRENT_SOURCE_DIR}/resources/icons/icon.ico")
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/src/windows_metadata.rc.in"
        "${CMAKE_CURRENT_BINARY_DIR}/windows_metadata.rc"
        @ONLY
    )
    set(WINDOWS_RESOURCES "${CMAKE_CURRENT_BINARY_DIR}/windows_metadata.rc")
else()
    set(WINDOWS_RESOURCES "")
endif()

set_source_files_properties(${QML_SINGLETONS}
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)

# Create executable with WIN32 flag only on Windows
if(WIN32)
    qt_add_executable(${PROJECT_NAME} WIN32
        ${HEADERS}
        ${SOURCES}
        resources/icons/icons.qrc
        resources/fonts/fonts.qrc
        ${WINDOWS_RESOURCES}
    )
else()
    qt_add_executable(${PROJECT_NAME}
        ${HEADERS}
        ${SOURCES}
        resources/icons/icons.qrc
        resources/fonts/fonts.qrc
    )
endif()

target_include_directories(${PROJECT_NAME} PRIVATE 
    include
    ${CMAKE_CURRENT_BINARY_DIR}
)

qt_add_qml_module(${PROJECT_NAME}
    URI Odizinne.OdznDrive
    VERSION 1.0
    QML_FILES ${QML_FILES} ${QML_SINGLETONS}
    SOURCES include/versionhelper.h src/versionhelper.cpp
    QML_FILES qml/Components/TransferStatus.qml
    QML_FILES qml/Dialogs/ConnectionLostDialog.qml
    QML_FILES qml/Dialogs/AdvancedSettingsDialog.qml
)

target_link_libraries(${PROJECT_NAME} PRIVATE
    Qt6::Core
    Qt6::Qml
    Qt6::Quick
    Qt6::Network
    Qt6::WebSockets
    Qt6::Widgets
)

if(WIN32)
    target_link_libraries(${PROJECT_NAME} PRIVATE dwmapi)
endif()

install(TARGETS ${PROJECT_NAME}
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

qt_generate_deploy_qml_app_script(
    TARGET ${PROJECT_NAME}
    OUTPUT_SCRIPT deploy_script
    NO_TRANSLATIONS
    DEPLOY_TOOL_OPTIONS --no-compiler-runtime --no-opengl-sw --no-system-dxc-compiler --no-system-d3d-compiler --skip-plugin-types designer,iconengines,qmllint,generic,networkinformation,help,qmltooling,sqldrivers,qmlls
)
install(SCRIPT ${deploy_script})

# -------------------------------------------
# Optional server subproject
# -------------------------------------------
option(BUILD_ODZNDRIVE_SERVER "Build the OdznDriveServer subproject" OFF)

if(BUILD_ODZNDRIVE_SERVER)
    add_subdirectory(Server)
endif()
