# (C) Copyright 1996-2015 ECMWF.
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
# In applying this licence, ECMWF does not waive the privileges and immunities
# granted to it by virtue of its status as an intergovernmental organisation nor
# does it submit to any jurisdiction.

##############################################################################
#.rst:
#
# ecbuild_use_package
# ===================
#
# Add a project from a source directory, a subdirectory or search for it. ::
#
#   ecbuild_use_package( PROJECT <name>
#                        [ VERSION <version> [ EXACT ] ]
#                        [ REQUIRED ]
#                        [ QUIET ] )
#
# Options
# -------
#
# NAME : required
#   package name (used as ``Find<name>.cmake`` and ``<name>-config.cmake``)
#
# VERSION : optional
#   minimum required package version
#
# EXACT : optional, requires VERSION
#   require the exact version rather than a minimum version
#
# REQUIRED : optional
#   fail if package cannot be found
#
# QUIET : optional
#   do not output package information if found
#
# Input variables
# ---------------
#
# The following CMake variables influence the behaviour if set (``<name>``
# is the package name as given, ``<NAME>`` is the capitalised version):
#
# :<NAME>_SOURCE:    path to source directory for package
# :SUBPROJECT_DIRS:  list of additional paths to search for package source
#
# See also ``ecbuild_find_package`` for additional CMake variables relevant
# when search for the package (step 6 below).
#
# Usage
# -----
#
# Use another CMake project as a dependency by either building it from source
# i.e. adding its source directory as a subdirectory or searching for it. This
# transparently deals with the case where the project has already been included
# e.g. because multiple projects with shared dependencies are built together.
#
# The search proceeds as follows:
#
# 1.  If ``SUBPROJECT_DIRS`` is set, each directory in the list is searched
#     for a subdirectory <name> and ``<NAME>_SOURCE`` is set to the first one
#     found (if any).
#
# 2.  If ``<NAME>_SOURCE`` is set, check if this directory is a CMake project
#     (contains ``CMakeLists.txt`` and fail if not.
#
# 3.  Otherwise, check if the current directory has a ``<name>`` subdirectory.
#
# 4.  If the project has not been previously marked as found or added as a
#     subdirectory and a project source directory has been found in steps 1-3
#     add this subdirectory.
#
# 5.  If the project has been marked as found, check the version.
#
# 6.  Otherwise, search for the project using ``ecbuild_find_package``.
#
##############################################################################

macro( ecbuild_use_package )

  set( options            REQUIRED QUIET EXACT )
  set( single_value_args  PROJECT VERSION )
  set( multi_value_args )

  cmake_parse_arguments( _p "${options}" "${single_value_args}" "${multi_value_args}"  ${_FIRST_ARG} ${ARGN} )

  if(_p_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "Unknown keywords given to ecbuild_use_package(): \"${_p_UNPARSED_ARGUMENTS}\"")
  endif()

  if( NOT _p_PROJECT  )
    message(FATAL_ERROR "The call to ecbuild_use_package() doesn't specify the PROJECT.")
  endif()

  if( _p_EXACT AND NOT _p_VERSION )
    message(FATAL_ERROR "Call to ecbuild_use_package() requests EXACT but doesn't specify VERSION.")
  endif()

  # try to find the package as a subproject and build it

  string( TOUPPER ${_p_PROJECT} pkgUPPER )

  # user defined dir with subprojects

  if( NOT DEFINED ${pkgUPPER}_SOURCE AND DEFINED SUBPROJECT_DIRS )
    ecbuild_warn("ecbuild_use_package(): setting SUBPROJECT_DIRS is deprecated")
    ecbuild_debug("ecbuild_use_package(${_p_PROJECT}): scanning subproject directories ${SUBPROJECT_DIRS}")
    foreach( dir ${SUBPROJECT_DIRS} )
      if( EXISTS ${dir}/${_p_PROJECT} AND EXISTS ${dir}/${_p_PROJECT}/CMakeLists.txt )
        ecbuild_debug("ecbuild_use_package(${_p_PROJECT}):   setting ${pkgUPPER}_SOURCE to ${dir}/${_p_PROJECT}")
        set( ${pkgUPPER}_SOURCE "${dir}/${_p_PROJECT}" )
      endif()
    endforeach()
  endif()

  # user defined path to subproject

  if( DEFINED ${pkgUPPER}_SOURCE )

    if( NOT EXISTS ${${pkgUPPER}_SOURCE} OR NOT EXISTS ${${pkgUPPER}_SOURCE}/CMakeLists.txt )
      ecbuild_critical("User defined source directory '${${pkgUPPER}_SOURCE}' for project '${_p_PROJECT}' does not exist or does not contain a CMakeLists.txt file.")
    endif()

    set( ${pkgUPPER}_subproj_dir_ "${${pkgUPPER}_SOURCE}" )

  else() # default is 'dropped in' subdirectory named as project

    if( EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${_p_PROJECT} AND EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${_p_PROJECT}/CMakeLists.txt )
      ecbuild_debug("ecbuild_use_package(${_p_PROJECT}): found ${_p_PROJECT} in subdirectory ${CMAKE_CURRENT_SOURCE_DIR}/${_p_PROJECT}")
      set( ${pkgUPPER}_subproj_dir_ "${CMAKE_CURRENT_SOURCE_DIR}/${_p_PROJECT}" )
    endif()

  endif()

  # check if was already added as subproject ...

  set( _just_added 0 )
  set( _do_version_check 0 )
  set( _source_description "" )

  list( FIND ECBUILD_PROJECTS ${_p_PROJECT} _ecbuild_project_${pkgUPPER} )

  if( NOT _ecbuild_project_${pkgUPPER} EQUAL "-1" )
    ecbuild_debug("ecbuild_use_package(${_p_PROJECT}): ${_p_PROJECT} was previously added as a subproject")
    set( ${pkgUPPER}_previous_subproj_ 1 )
  else()
    ecbuild_debug("ecbuild_use_package(${_p_PROJECT}): ${_p_PROJECT} was not previously added as a subproject")
    set( ${pkgUPPER}_previous_subproj_ 0 )
  endif()

  # solve capitalization issues

  if( ${_p_PROJECT}_FOUND AND NOT ${pkgUPPER}_FOUND )
    set( ${pkgUPPER}_FOUND 1 )
  endif()
  if( ${pkgUPPER}_FOUND AND NOT ${_p_PROJECT}_FOUND )
    set( ${_p_PROJECT}_FOUND 1 )
  endif()

  # Case 1) project was NOT previously added as subproject and is NOT already FOUND

  if( NOT ${pkgUPPER}_FOUND AND NOT ${pkgUPPER}_previous_subproj_ )

    # check if SUBPROJDIR is set

    if( DEFINED ${pkgUPPER}_subproj_dir_ )

      ecbuild_debug("ecbuild_use_package(${_p_PROJECT}): 1) project was NOT previously added as subproject and is NOT already FOUND")

      # check version is acceptable
      set( _just_added 1 )
      set( _do_version_check 1 )
      set( _source_description "sub-project ${_p_PROJECT} (sources)" )

      # add as a subproject

      set( ${pkgUPPER}_subproj_dir_ ${${pkgUPPER}_subproj_dir_} CACHE PATH "Path to ${_p_PROJECT} source directory" )

      set( ECBUILD_PROJECTS ${ECBUILD_PROJECTS} ${_p_PROJECT} CACHE INTERNAL "" )

      ecbuild_debug("ecbuild_use_package(${_p_PROJECT}):    ${_p_PROJECT} found in subdirectory ${${pkgUPPER}_subproj_dir_}")
      add_subdirectory( ${${pkgUPPER}_subproj_dir_} ${_p_PROJECT} )

      set( ${_p_PROJECT}_BASE_DIR ${CMAKE_BINARY_DIR} )

      set( ${pkgUPPER}_FOUND 1 )
      set( ${_p_PROJECT}_VERSION ${${pkgUPPER}_VERSION} )

      list( APPEND ${pkgUPPER}_INCLUDE_DIRS ${${pkgUPPER}_TPL_INCLUDE_DIRS} )

    endif()

  endif()

  # Case 2) project was already added as subproject, so is already FOUND -- BUT must check version acceptable

  if( ${pkgUPPER}_previous_subproj_ )

    ecbuild_debug("ecbuild_use_package(${_p_PROJECT}): 2) project was already added as subproject, check version is acceptable")

    if( NOT ${pkgUPPER}_FOUND )
      message( FATAL_ERROR "${_p_PROJECT} was already included as sub-project but ${pkgUPPER}_FOUND isn't set -- this is likely a BUG in ecbuild" )
    endif()

    # check version is acceptable
    set( _do_version_check 1 )
    set( _source_description "already existing sub-project ${_p_PROJECT} (sources)" )

  endif()

  # Case 3) project was NOT added as subproject, but is FOUND -- so it was previously found as a binary ( either build or install tree )

  if( ${pkgUPPER}_FOUND AND NOT ${pkgUPPER}_previous_subproj_ AND NOT _just_added )

    ecbuild_debug("ecbuild_use_package(${_p_PROJECT}): 3) project was NOT previously added as subproject, but is FOUND")

    # check version is acceptable
    set( _do_version_check 1 )
    set( _source_description "previously found package ${_p_PROJECT} (binaries)" )

  endif()

  # test version for Cases 1,2,3

  # ecbuild_debug_var( _p_PROJECT )
  # ecbuild_debug_var( _p_VERSION )
  # ecbuild_debug_var( ${pkgUPPER}_VERSION )
  # ecbuild_debug_var( ${_p_PROJECT}_VERSION )
  # ecbuild_debug_var( _just_added )
  # ecbuild_debug_var( _do_version_check )
  # ecbuild_debug_var( _source_description )
  # ecbuild_debug_var( ${pkgUPPER}_FOUND )
  # ecbuild_debug_var( ${pkgUPPER}_previous_subproj_ )

  if( _p_VERSION AND _do_version_check )
    if( _p_EXACT )
      if( NOT ${_p_PROJECT}_VERSION VERSION_EQUAL _p_VERSION )
        message( FATAL_ERROR "${PROJECT_NAME} requires (exactly) ${_p_PROJECT} = ${_p_VERSION} -- detected as ${_source_description} ${${_p_PROJECT}_VERSION}" )
      endif()
    else()
      if( _p_VERSION VERSION_LESS ${_p_PROJECT}_VERSION OR _p_VERSION VERSION_EQUAL ${_p_PROJECT}_VERSION )
        message( STATUS "${PROJECT_NAME} requires ${_p_PROJECT} >= ${_p_VERSION} -- detected as ${_source_description} ${${_p_PROJECT}_VERSION}" )
      else()
        message( FATAL_ERROR "${PROJECT_NAME} requires ${_p_PROJECT} >= ${_p_VERSION} -- detected only ${_source_description} ${${_p_PROJECT}_VERSION}" )
      endif()
    endif()
  endif()

  # Case 4) is NOT FOUND so far, NOT as sub-project (now or before), and NOT as binary neither
  #         so try to find precompiled binaries or a build tree

  if( NOT ${pkgUPPER}_FOUND )

    ecbuild_debug("ecbuild_use_package(${_p_PROJECT}): 4) project has NOT been added as a subproject and is NOT already FOUND")

    set( _opts )
    if( _p_VERSION )
      list( APPEND _opts VERSION ${_p_VERSION} )
    endif()
    if( _p_EXACT )
      list( APPEND _opts EXACT )
    endif()
    if( _p_REQUIRED )
      list( APPEND _opts REQUIRED )
    endif()

    ecbuild_find_package( NAME ${_p_PROJECT} ${_opts} )

    if( ${_p_PROJECT}_FOUND )
      set( ${pkgUPPER}_FOUND ${${_p_PROJECT}_FOUND} )
    endif()

  endif()

  if( ${pkgUPPER}_FOUND )
    list( APPEND ${PROJECT_NAME_CAPS}_TPLS ${_p_PROJECT} )
    list( REMOVE_DUPLICATES ${PROJECT_NAME_CAPS}_TPLS )
  endif()

  ### for when we change this macro to a function()
  # set_parent_scope( ${pkgUPPER}_FOUND )
  # set_parent_scope( ${_p_PROJECT}_FOUND )
  # set_parent_scope( ${pkgUPPER}_VERSION )
  # set_parent_scope( ${_p_PROJECT}_VERSION )
  # set_parent_scope( ${_p_PROJECT}_BINARY_DIR )

endmacro()
