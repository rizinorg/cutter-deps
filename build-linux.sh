#!/bin/bash

PYTHON_SRC_FILE=Python-3.6.4.tar.xz
PYTHON_SRC_MD5=1325134dd525b4a2c3272a1a0214dd54
PYTHON_SRC_URL=https://www.python.org/ftp/python/3.6.4/Python-3.6.4.tar.xz

PATCHELF_SRC_FILE=patchelf-0.9.tar.bz2
PATCHELF_SRC_MD5=d02687629c7e1698a486a93a0d607947
PATCHELF_SRC_URL=https://nixos.org/releases/patchelf/patchelf-0.9/patchelf-0.9.tar.bz2

QT_SRC_FILE=qt-everywhere-src-5.12.1.tar.xz
QT_SRC_MD5=6a37466c8c40e87d4a19c3f286ec2542
QT_SRC_URL=https://download.qt.io/official_releases/qt/5.12/5.12.1/single/qt-everywhere-src-5.12.1.tar.xz

PYSIDE_SRC_FILE=pyside-setup-everywhere-src-5.12.1.tar.xz
PYSIDE_SRC_MD5=c247fc1de38929d81aedd1c93d629d9e
PYSIDE_SRC_URL=https://download.qt.io/official_releases/QtForPython/pyside2/PySide2-5.12.1-src/pyside-setup-everywhere-src-5.12.1.tar.xz

BUILD_THREADS=8

ROOT_DIR="$PWD"
PYTHON_PREFIX="$PWD/python"
QT_PREFIX="$PWD/qt"
PYSIDE_PREFIX="$PWD/pyside"

cd "$(dirname "$0")"

check_md5() {
	echo "$2 $1" | md5sum -c - || exit 1
}

download() {
	if [ ! -f "$2" ]; then
		echo "Downloading $2"
		curl -L "$1" -o "$2" || exit 1
	fi
	check_md5 "$2" "$3"
}

build_python() {
	echo ""
	echo "#########################"
	echo "# Building Python       #"
	echo "#########################"
	echo ""

	cd Python-3.6.4 || exit 1

	echo "Building Python to install to prefix $PYTHON_PREFIX"
	./configure --enable-shared --prefix="$PYTHON_PREFIX" || exit 1
	make -j$BUILD_THREADS || exit 1
	make install > /dev/null || exit 1
	cd "$ROOT_DIR"

	echo "Patching libs in $CUSTOM_PYTHON_PREFIX/lib/python3.6/lib-dynload to have the correct rpath"
	cd patchelf-0.9 || exit 1
	PATCHELF_DIR="$PWD"
	./configure || exit 1
	make || exit 1
	
	for lib in "$PYTHON_PREFIX/lib/python3.6/lib-dynload"/*.so; do
		echo "  patching $lib"
	    "$PATCHELF_DIR/src/patchelf" --set-rpath '$ORIGIN/../..' "$lib" || exit 1
	done


	cd "$ROOT_DIR"
}

build_qt() {
	echo ""
	echo "#########################"
	echo "# Building Qt5          #"
	echo "#########################"
	echo ""

	cd qt-everywhere-src-5.12.1 || exit 1
	mkdir -p build && cd build || exit 1
	
	../configure \
		-prefix "`pwd`/../../qt" \
		-opensource -confirm-license \
		-release \
		-no-opengl \
		-no-feature-cups \
		-no-sql-db2 -no-sql-ibase -no-sql-mysql -no-sql-oci -no-sql-odbc -no-sql-psql -no-sql-sqlite2 -no-sql-sqlite -no-sql-tds \
		-nomake tests -nomake examples \
		-skip qtwebengine \
		-skip qt3d \
		-skip qtcanvas3d \
		-skip qtcharts \
		-skip qtconnectivity \
		-skip qtdeclarative \
		-skip qtdoc \
		-skip qtscript \
		-skip qtdatavis3d \
		-skip qtgamepad \
		-skip qtlocation \
		-skip qtgraphicaleffects \
		-skip qtmultimedia \
		-skip qtpurchasing \
		-skip qtscxml \
		-skip qtsensors \
		-skip qtserialbus \
		-skip qtserialport \
		-skip qtspeech \
		-skip qttools \
		-skip qttranslations \
		-skip qtvirtualkeyboard \
		-skip qtwebglplugin \
		-skip qtwebsockets \
		-skip qtwebview \
		|| exit 1
	
	make -j$BUILD_THREAD || exit 1
	make install > /dev/null || exit 1
	
	cd ../..
}

build_pyside() {
	echo ""
	echo "#########################"
	echo "# Preparing PySide2     #"
	echo "#########################"
	echo ""

	cd pyside-setup-everywhere-src-5.12.1 || exit 1
	
	# Patch needed, so the PySide2 CMakeLists.txt doesn't search for Qt5UiTools and other stuff,
	# which would mess up finding the actual modules later.
	patch sources/pyside2/CMakeLists.txt ../patch/pyside2-CMakeLists.txt.patch || exit 1
	echo "" > sources/pyside2/cmake/Macros/FindQt5Extra.cmake || exit 1
	
	# Patches to remove OpenGL-related source files.
	patch sources/pyside2/PySide2/QtGui/CMakeLists.txt ../patch/pyside2-QtGui-CMakeLists.txt.patch || exit 1
	patch sources/pyside2/PySide2/QtWidgets/CMakeLists.txt ../patch/pyside2-QtWidgets-CMakeLists.txt.patch || exit 1
	
	mkdir -p build && cd build || exit 1
	
	export LD_LIBRARY_PATH="$PYTHON_PREFIX/lib:$LD_LIBRARY_PATH"

	PYTHON_VERSION=3

	echo ""
	echo "#########################"
	echo "# Building Shiboken2    #"
	echo "#########################"
	echo ""
	
	mkdir -p shiboken2 && cd shiboken2 || exit 1
	cmake \
		-DCMAKE_PREFIX_PATH="$QT_PREFIX" \
		-DCMAKE_INSTALL_PREFIX="$PYSIDE_PREFIX" \
		-DUSE_PYTHON_VERSION=$PYTHON_VERSION \
		-DPYTHON_LIBRARY="$PYTHON_PREFIX/lib/libpython3.so" \
		-DPYTHON_INCLUDE_DIR="$PYTHON_PREFIX/include/python3.6m" \
		-DPYTHON_EXECUTABLE="$PYTHON_PREFIX/bin/python3.6" \
		-DBUILD_TESTS=OFF \
		-DCMAKE_BUILD_TYPE=Release \
		../../sources/shiboken2 || exit 1
	make -j$BUILD_THREADS || exit 1
	make install || exit 1
	cd ..

	echo ""
	echo "#########################"
	echo "# Building PySide2      #"
	echo "#########################"
	echo ""
	
	mkdir -p pyside2 && cd pyside2 || exit 1
	cmake \
		-DCMAKE_PREFIX_PATH="$QT_PREFIX;$PYSIDE_PREFIX" \
		-DCMAKE_INSTALL_PREFIX="$PYSIDE_PREFIX" \
		-DUSE_PYTHON_VERSION=$PYTHON_VERSION \
		-DPYTHON_LIBRARY="$PYTHON_PREFIX/lib/libpython3.so" \
		-DPYTHON_INCLUDE_DIR="$PYTHON_PREFIX/include/python3.6m" \
		-DPYTHON_EXECUTABLE="$PYTHON_PREFIX/bin/python3.6" \
		-DBUILD_TESTS=OFF \
		-DCMAKE_BUILD_TYPE=Release \
		-DMODULES="Core;Gui;Widgets" \
		../../sources/pyside2 || exit 1
	make -j$BUILD_THREADS || exit 1
	make install || exit 1
	cd ..
	
	cd ..
}

download "$QT_SRC_URL" "$QT_SRC_FILE" "$QT_SRC_MD5"
tar -xf "$QT_SRC_FILE" || exit 1
download "$PYSIDE_SRC_URL" "$PYSIDE_SRC_FILE" "$PYSIDE_SRC_MD5"
tar -xf "$PYSIDE_SRC_FILE" || exit 1
download "$PYTHON_SRC_URL" "$PYTHON_SRC_FILE" "$PYTHON_SRC_MD5"
tar -xf "$PYTHON_SRC_FILE" || exit 1
download "$PATCHELF_SRC_URL" "$PATCHELF_SRC_FILE" "$PATCHELF_SRC_MD5"
tar -xf "$PATCHELF_SRC_FILE" || exit 1

build_python
build_qt
build_pyside

echo ""
echo "#########################"
echo "# Creating archive      #"
echo "#########################"
echo ""

tar -czf cutter-deps.tar.gz qt python pyside || exit 1

