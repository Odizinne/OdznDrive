cmake_minimum_required(VERSION 3.21)
project(OdznDriveServer VERSION 0.14.2 LANGUAGES CXX)
set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install" CACHE PATH "Installation directory" FORCE)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTORCC ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Network WebSockets HttpServer Core5Compat)
qt_standard_project_setup()
include(FetchContent)

# Fetch zlib WITH -fPIC
FetchContent_Declare(
    zlib
    GIT_REPOSITORY https://github.com/madler/zlib.git
    GIT_TAG v1.3.1
)

# Force zlib to build with -fPIC
set(CMAKE_POSITION_INDEPENDENT_CODE ON CACHE BOOL "Build with -fPIC" FORCE)
FetchContent_MakeAvailable(zlib)

# Create ZLIB::ZLIB alias that QuaZip expects
if(NOT TARGET ZLIB::ZLIB)
    add_library(ZLIB::ZLIB ALIAS zlibstatic)
    set_target_properties(zlibstatic PROPERTIES POSITION_INDEPENDENT_CODE ON)
endif()

# Set variables for find_package(ZLIB) to succeed
set(ZLIB_INCLUDE_DIRS "${zlib_SOURCE_DIR};${zlib_BINARY_DIR}" CACHE PATH "zlib include" FORCE)
set(ZLIB_INCLUDE_DIR "${zlib_SOURCE_DIR};${zlib_BINARY_DIR}" CACHE PATH "zlib include" FORCE)
set(ZLIB_LIBRARIES ZLIB::ZLIB CACHE STRING "zlib library" FORCE)
set(ZLIB_LIBRARY ZLIB::ZLIB CACHE STRING "zlib library" FORCE)
set(ZLIB_FOUND TRUE CACHE BOOL "zlib found" FORCE)
set(ZLIB_VERSION_STRING "1.3.1" CACHE STRING "zlib version" FORCE)

# Fetch QuaZip
FetchContent_Declare(
    QuaZip
    GIT_REPOSITORY https://github.com/stachenov/quazip.git
    GIT_TAG v1.5
)
set(QUAZIP_QT_MAJOR_VERSION 6 CACHE STRING "Qt version" FORCE)
set(QUAZIP_INSTALL OFF CACHE BOOL "Install QuaZip" FORCE)
FetchContent_MakeAvailable(QuaZip)

set(SOURCES
    src/main.cpp
    src/fileserver.cpp
    src/clientconnection.cpp
    src/filemanager.cpp
    src/config.cpp
    src/httpserver.cpp
)

set(HEADERS
    include/fileserver.h
    include/clientconnection.h
    include/filemanager.h
    include/config.h
    include/httpserver.h
)

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

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/src/version.h.in"
    "${CMAKE_CURRENT_BINARY_DIR}/version.h"
)

qt_add_executable(${PROJECT_NAME}
    ${SOURCES}
    ${HEADERS}
    resources/resources.qrc
    include/protocol.h
)

target_include_directories(${PROJECT_NAME} PRIVATE
    include
    ${CMAKE_CURRENT_BINARY_DIR}
)

target_link_libraries(${PROJECT_NAME} PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Network
    Qt6::WebSockets
    Qt6::HttpServer
    Qt6::Core5Compat
    QuaZip::QuaZip
)

install(TARGETS ${PROJECT_NAME}
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

qt_generate_deploy_app_script(
    TARGET ${PROJECT_NAME}
    OUTPUT_SCRIPT deploy_script
    NO_TRANSLATIONS
    DEPLOY_TOOL_OPTIONS --no-compiler-runtime --no-opengl-sw --no-system-dxc-compiler --no-system-d3d-compiler --skip-plugin-types designer,iconengines,qmllint,generic,networkinformation,help,qmltooling,sqldrivers,qmlls
)

install(SCRIPT ${deploy_script})
