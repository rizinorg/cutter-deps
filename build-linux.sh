
QT_SRC_FILE=qt-everywhere-src-5.12.1.tar.xz
QT_SRC_MD5=6a37466c8c40e87d4a19c3f286ec2542
QT_SRC_URL=https://download.qt.io/official_releases/qt/5.12/5.12.1/single/qt-everywhere-src-5.12.1.tar.xz

PYSIDE_SRC_FILE=pyside-setup-everywhere-src-5.12.1.tar.xz
PYSIDE_SRC_MD5=c247fc1de38929d81aedd1c93d629d9e
PYSIDE_SRC_URL=https://download.qt.io/official_releases/QtForPython/pyside2/PySide2-5.12.1-src/pyside-setup-everywhere-src-5.12.1.tar.xz

BUILD_THREADS=8

cd "$(dirname "$0")"

check_md5() {
	echo "$2 $1" | md5sum -c - || exit 1
}

download() {
	if [ ! -f "$2" ]; then
		curl -L "$1" -o "$2" || exit 1
	fi
	check_md5 "$2" "$3"
}

#download "$QT_SRC_URL" "$QT_SRC_FILE" "$QT_SRC_MD5"
#tar -xf "$QT_SRC_FILE" || exit 1
download "$PYSIDE_SRC_URL" "$PYSIDE_SRC_FILE" "$PYSIDE_SRC_MD5"
tar -xf "$PYSIDE_SRC_FILE" || exit 1

QT_PREFIX="$PWD/qt"
PYSIDE_PREFIX="$PWD/pyside"

#####################
# Build PySide2
#####################

cd pyside-setup-everywhere-src-5.12.1 || exit 1

# Patch needed, so the PySide2 CMakeLists.txt doesn't search for Qt5UiTools and other stuff,
# which would mess up finding the actual modules later.
patch sources/pyside2/CMakeLists.txt ../patch/pyside2-CMakeLists.txt.patch || exit 1
echo "" > sources/pyside2/cmake/Macros/FindQt5Extra.cmake || exit 1
#cp ../patch/CMakeLists.txt sources/pyside2/CMakeLists.txt || exit 1

mkdir -p build && cd build || exit 1

PYTHON_VERSION=3

mkdir -p shiboken2 && cd shiboken2 || exit 1
cmake \
	-DCMAKE_PREFIX_PATH="$QT_PREFIX" \
	-DCMAKE_INSTALL_PREFIX="$PYSIDE_PREFIX" \
	-DUSE_PYTHON_VERSION=$PYTHON_VERSION \
	-DBUILD_TESTS=OFF \
	-DCMAKE_BUILD_TYPE=Release \
	../../sources/shiboken2 || exit 1
make -j$BUILD_THREADS || exit 1
make install || exit 1
cd ..

mkdir -p pyside2 && cd pyside2 || exit 1
cmake \
	-DCMAKE_PREFIX_PATH=$QT_PREFIX \
	-DCMAKE_INSTALL_PREFIX="$PYSIDE_PREFIX" \
	-DUSE_PYTHON_VERSION=$PYTHON_VERSION \
	-DBUILD_TESTS=OFF \
	-DCMAKE_BUILD_TYPE=Release \
	-DMODULES="Core;Gui;Widgets" \
	../../sources/pyside2 || exit 1
#make -j$BUILD_THREADS || exit 1
#make install || exit 1
cd ..

#python setup.py --qmake=../qt/bin/qmake --module-subset=Core,Gui,Widgets --skip-packaging build 
exit 0

#####################
# Build Qt
#####################

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

