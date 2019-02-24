#!/bin/bash

CUTTER_DEPS_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

export CUTTER_DEPS_PYTHON_PREFIX="$CUTTER_DEPS_ROOT/python"

export LD_LIBRARY_PATH="$CUTTER_DEPS_ROOT/qt/lib:$CUTTER_DEPS_ROOT/python/lib:$CUTTER_DEPS_ROOT/pyside/lib:$LD_LIBRARY_PATH"
export PATH="$CUTTER_DEPS_ROOT/qt/bin:$CUTTER_DEPS_ROOT/python/bin:$CUTTER_DEPS_ROOT/pyside/bin:$PATH"

export PKG_CONFIG_PATH="$CUTTER_DEPS_ROOT/qt/lib/pkgconfig:$CUTTER_DEPS_ROOT/python/lib/pkgconfig:$CUTTER_DEPS_ROOT/pyside/lib/pkgconfig"

# For QMake
export QTDIR="$CUTTER_DEPS_ROOT/qt"

# For CMake
export Qt5_ROOT="$CUTTER_DEPS_ROOT/qt"
export PythonLibs_ROOT="$CUTTER_DEPS_ROOT/python"
export PythonInterp_ROOT="$CUTTER_DEPS_ROOT/python"
export Shiboken2_ROOT="$CUTTER_DEPS_ROOT/pyside"
export PySide2_ROOT="$CUTTER_DEPS_ROOT/pyside"

