project(OdznDriveClient)

set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install" CACHE PATH "Installation directory" FORCE)
qt_standard_project_setup(REQUIRES 6.8)

set(SOURCES
    src/main.cpp
    src/connectionmanager.cpp
    src/filemodel.cpp
)

set(HEADERS
    include/connectionmanager.h
    include/filemodel.h
)

set(QML_FILES
    qml/Main.qml
    qml/HeaderBar.qml
    qml/FileListView.qml
    qml/TransferProgress.qml
)

qt_add_executable(${PROJECT_NAME}
    ${HEADERS}
    ${SOURCES}
)

target_include_directories(${PROJECT_NAME} PRIVATE include)

qt_add_qml_module(${PROJECT_NAME}
    URI Odizinne.OdznDriveClient
    VERSION 1.0
    QML_FILES ${QML_FILES}
)

target_link_libraries(${PROJECT_NAME} PRIVATE
    Qt6::Core
    Qt6::Qml
    Qt6::Quick
    Qt6::Network
    Qt6::WebSockets
)

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
