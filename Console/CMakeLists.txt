cmake_minimum_required(VERSION 3.15)
project(console LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

file(GLOB_RECURSE SRC_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/Network/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/Depth/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/RGB/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/IMU/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp
)

add_executable(console ${SRC_FILES})

target_include_directories(console PRIVATE
                            ${CMAKE_CURRENT_SOURCE_DIR}/Network
                            ${CMAKE_CURRENT_SOURCE_DIR}/Depth
                            ${CMAKE_CURRENT_SOURCE_DIR}/RGB
                            ${CMAKE_CURRENT_SOURCE_DIR}/IMU)

