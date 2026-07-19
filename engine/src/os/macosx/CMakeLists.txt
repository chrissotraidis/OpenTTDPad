add_files(
    crashlog_osx.cpp
    font_osx.cpp
    font_osx.h
    macos.h
    macos.mm
    osx_stdafx.h
    string_osx.cpp
    string_osx.h
    survey_osx.cpp
    CONDITION APPLE AND NOT OPENTTDPAD_IOS
)

if(APPLE AND NOT OPENTTDPAD_IOS)
    target_sources(openttd PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/osx_main.cpp)
endif()
