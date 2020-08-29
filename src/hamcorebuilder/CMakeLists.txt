add_executable(hamcorebuilder hamcorebuilder.c)

target_link_libraries(hamcorebuilder cedar mayaqua)

set_target_properties(hamcorebuilder
  PROPERTIES
  ARCHIVE_OUTPUT_DIRECTORY "${TOP_DIRECTORY}/src/bin/hamcore"
  LIBRARY_OUTPUT_DIRECTORY "${TOP_DIRECTORY}/src/bin/hamcore"
  RUNTIME_OUTPUT_DIRECTORY "${TOP_DIRECTORY}/src/bin/hamcore"
)
