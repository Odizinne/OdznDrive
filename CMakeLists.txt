cmake_minimum_required(VERSION 3.21)

project(OdznDrive VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Network WebSockets Qml Quick)

add_subdirectory(Server)
add_subdirectory(Client)
