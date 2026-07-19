if(NOT IS_ABSOLUTE "${OPENTTDPAD_UI_TEST_PROJECT}")
    message(FATAL_ERROR "OPENTTDPAD_UI_TEST_PROJECT must be absolute")
endif()

configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/OpenTTDPadUITests.xcscheme"
    "${OPENTTDPAD_UI_TEST_SCHEME}"
    @ONLY
)
