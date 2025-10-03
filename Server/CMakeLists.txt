project(OdznDriveServer)

qt_standard_project_setup()

set(SOURCES
    src/main.cpp
    src/fileserver.cpp
    src/clientconnection.cpp
    src/filemanager.cpp
    src/config.cpp
)

set(HEADERS
    include/fileserver.h
    include/clientconnection.h
    include/filemanager.h
    include/config.h
)

add_executable(${PROJECT_NAME} ${SOURCES} ${HEADERS})

target_include_directories(${PROJECT_NAME} PRIVATE include)

target_link_libraries(${PROJECT_NAME} PRIVATE
    Qt6::Core
    Qt6::Network
    Qt6::WebSockets
)

install(TARGETS ${PROJECT_NAME}
    RUNTIME DESTINATION Server/bin
    COMPONENT Server
)

qt_generate_deploy_app_script(
    TARGET ${PROJECT_NAME}
    OUTPUT_SCRIPT deploy_script
    NO_TRANSLATIONS
    DEPLOY_TOOL_OPTIONS --no-compiler-runtime --no-opengl-sw --no-system-dxc-compiler --no-system-d3d-compiler --skip-plugin-types designer,iconengines,qmllint,generic,networkinformation,help,qmltooling,sqldrivers,qmlls
)

install(SCRIPT ${deploy_script} COMPONENT Server)
