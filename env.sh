#!/bin/bash

CUTTER_DEPS_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

export CUTTER_DEPS_PYTHON_PREFIX="$CUTTER_DEPS_ROOT/python"

export LD_LIBRARY_PATH="$CUTTER_DEPS_ROOT/qt/lib:`pwd`/python/lib:`pwd`/pyside/lib:$LD_LIBRARY_PATH"
export PATH="$CUTTER_DEPS_ROOT/qt/bin:`pwd`/python/bin:`pwd`/pyside/bin:$PATH"

export PKG_CONFIG_PATH="$CUTTER_DEPS_ROOT/qt/lib/pkgconfig:`pwd`/python/lib/pkgconfig:`pwd`/pyside/lib/pkgconfig"

# For CMake
export Qt5_ROOT="$CUTTER_DEPS_ROOT/qt"
export PythonLibs_ROOT="$CUTTER_DEPS_ROOT/python"
export PythonInterp_ROOT="$CUTTER_DEPS_ROOT/python"
export Shiboken2_ROOT="$CUTTER_DEPS_ROOT/pyside"
export PySide2_ROOT="$CUTTER_DEPS_ROOT/pyside"

