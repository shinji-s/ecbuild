
ecbuild_add_test(
  TARGET     test_ecbuild_remove_fortran_flags
  TYPE       SCRIPT
  COMMAND    ${CMAKE_COMMAND}
  ARGS       -DCMAKE_MODULE_PATH=${ECBUILD_MACROS_DIR}
             -P ${CMAKE_CURRENT_SOURCE_DIR}/test_ecbuild_remove_fortran_flags.cmake
)
