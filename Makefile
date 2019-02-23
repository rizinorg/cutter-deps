
ROOT_DIR=${CURDIR}

PYTHON_SRC_FILE=Python-3.6.4.tar.xz
PYTHON_SRC_MD5=1325134dd525b4a2c3272a1a0214dd54
PYTHON_SRC_URL=https://www.python.org/ftp/python/3.6.4/Python-3.6.4.tar.xz
PYTHON_SRC_DIR=Python-3.6.4
PYTHON_PREFIX=${ROOT_DIR}/python
${PYTHON_SRC_DIR}_target=PYTHON_SRC
PYTHON_LIBRARY=${PYTHON_PREFIX}/lib/libpython3.so
PYTHON_INCLUDE_DIR=${PYTHON_PREFIX}/include/python3.6m
PYTHON_EXECUTABLE=${PYTHON_PREFIX}/bin/python3


PATCHELF_SRC_FILE=patchelf-0.9.tar.bz2
PATCHELF_SRC_MD5=d02687629c7e1698a486a93a0d607947
PATCHELF_SRC_URL=https://nixos.org/releases/patchelf/patchelf-0.9/patchelf-0.9.tar.bz2

#QT_SRC_FILE=qt-everywhere-src-5.12.1.tar.xz
#QT_SRC_MD5=6a37466c8c40e87d4a19c3f286ec2542
#QT_SRC_URL=https://download.qt.io/official_releases/qt/5.12/5.12.1/single/qt-everywhere-src-5.12.1.tar.xz

QT_BIN_FILE=cutter-deps-qt.tar.gz
QT_BIN_URL=https://github.com/thestr4ng3r/cutter-deps-qt/releases/download/v1/cutter-deps-qt.tar.gz
QT_BIN_MD5=6e14fd8e804954feeadc67776063e0c6
QT_BIN_DIR=qt
QT_PREFIX=${ROOT_DIR}/${QT_BIN_DIR}
${QT_BIN_DIR}_target=QT_BIN

#PYSIDE_SRC_FILE=pyside-setup-everywhere-src-5.12.1.tar.xz
#PYSIDE_SRC_MD5=c247fc1de38929d81aedd1c93d629d9e
#PYSIDE_SRC_URL=https://download.qt.io/official_releases/QtForPython/pyside2/PySide2-5.12.1-src/pyside-setup-everywhere-src-5.12.1.tar.xz
#PYSIDE_SRC_DIR=pyside-setup-everywhere-src-5.12.1
PYSIDE_SRC_DIR=pyside-src
PYSIDE_SRC_GIT=https://code.qt.io/pyside/pyside-setup.git
PYSIDE_SRC_GIT_COMMIT=7a7952fc2e0809ef7f12a726376cec457897c364
PYSIDE_PREFIX=${ROOT_DIR}/pyside

PACKAGE_FILE=cutter-deps.tar.gz

BUILD_THREADS=4

LLVM_LIBDIR=$(shell llvm-config --libdir)
export LD_LIBRARY_PATH := ${PYTHON_PREFIX}/lib:${QT_PREFIX}/lib:${LLVM_LIBDIR}:${LD_LIBRARY_PATH}

all: python qt pyside pkg

.PHONY: clean
clean: clean-python clean-qt clean-pyside

.PHONY: distclean
distclean: distclean-python distclean-qt distclean-pyside distclean-pkg

# Download Targets

define download_extract
	curl -L "$1" -o "$2"
	echo "$3 $2" | md5sum -c -
	tar -xf "$2"
endef

${PYTHON_SRC_DIR} ${QT_BIN_DIR}:
	@echo ""
	@echo "#########################"
	@echo "# Downloading ${$@_target}"
	@echo "#########################"
	@echo ""
	$(call download_extract,${${$@_target}_URL},${${$@_target}_FILE},${${$@_target}_MD5})


# Python

python: ${PYTHON_SRC_DIR}
	@echo ""
	@echo "#########################"
	@echo "# Building Python       #"
	@echo "#########################"
	@echo ""

	cd "${PYTHON_SRC_DIR}" && ./configure --enable-shared --prefix="${PYTHON_PREFIX}"
	make -C "${PYTHON_SRC_DIR}" -j${BUILD_THREADS} > /dev/null
	make -C "${PYTHON_SRC_DIR}" install > /dev/null
	
.PHONY: clean-python
clean-python:
	rm -f "${PYTHON_SRC_FILE}"
	rm -rf "${PYTHON_SRC_DIR}"

.PHONY: distclean-python
distclean-python: clean-python
	rm -rf "${PYTHON_PREFIX}"


# Qt

.PHONY: clean-qt
clean-qt:
	rm -f "${QT_BIN_FILE}"
	rm -rf "${QT_BIN_DIR}"

distclean-qt: clean-qt

# Shiboken2 + PySide2

${PYSIDE_SRC_DIR}:
	@echo ""
	@echo "#########################"
	@echo "# Downloading PySide2   #"
	@echo "#########################"
	@echo ""

	git clone "${PYSIDE_SRC_GIT}" "${PYSIDE_SRC_DIR}"
	cd "${PYSIDE_SRC_DIR}" && git checkout "${PYSIDE_SRC_GIT_COMMIT}"
	
	# Patch needed, so the PySide2 CMakeLists.txt doesn't search for Qt5UiTools and other stuff,
	# which would mess up finding the actual modules later.
	patch "${PYSIDE_SRC_DIR}/sources/pyside2/CMakeLists.txt" patch/pyside2-CMakeLists.txt.patch
	echo "" > "${PYSIDE_SRC_DIR}/sources/pyside2/cmake/Macros/FindQt5Extra.cmake"

	# Patches to remove OpenGL-related source files.
	patch "${PYSIDE_SRC_DIR}/sources/pyside2/PySide2/QtGui/CMakeLists.txt" patch/pyside2-QtGui-CMakeLists.txt.patch
	patch "${PYSIDE_SRC_DIR}/sources/pyside2/PySide2/QtWidgets/CMakeLists.txt" patch/pyside2-QtWidgets-CMakeLists.txt.patch

pyside: python qt ${PYSIDE_SRC_DIR}
	@echo ""
	@echo "#########################"
	@echo "# Building Shiboken2    #"
	@echo "#########################"
	@echo ""

	echo "${LD_LIBRARY_PATH}"

	mkdir -p "${PYSIDE_SRC_DIR}/build/shiboken2"
	cd "${PYSIDE_SRC_DIR}/build/shiboken2" && cmake \
		-DCMAKE_PREFIX_PATH="${QT_PREFIX}" \
		-DCMAKE_INSTALL_PREFIX="${PYSIDE_PREFIX}" \
		-DUSE_PYTHON_VERSION=3 \
		-DPYTHON_LIBRARY="${PYTHON_LIBRARY}" \
		-DPYTHON_INCLUDE_DIR="${PYTHON_INCLUDE_DIR}" \
		-DPYTHON_EXECUTABLE="${PYTHON_EXECUTABLE}" \
		-DBUILD_TESTS=OFF \
		-DCMAKE_BUILD_TYPE=Release \
		../../sources/shiboken2
	make -C "${PYSIDE_SRC_DIR}/build/shiboken2" -j${BUILD_THREADS} > /dev/null
	make -C "${PYSIDE_SRC_DIR}/build/shiboken2" install > /dev/null

	@echo ""
	@echo "#########################"
	@echo "# Building PySide2      #"
	@echo "#########################"
	@echo ""

	mkdir -p "${PYSIDE_SRC_DIR}/build/pyside2"
	cd "${PYSIDE_SRC_DIR}/build/pyside2" && cmake \
		-DCMAKE_PREFIX_PATH="${QT_PREFIX};${PYSIDE_PREFIX}" \
		-DCMAKE_INSTALL_PREFIX="${PYSIDE_PREFIX}" \
		-DUSE_PYTHON_VERSION=3 \
		-DPYTHON_LIBRARY="${PYTHON_LIBRARY}" \
		-DPYTHON_INCLUDE_DIR="${PYTHON_INCLUDE_DIR}" \
		-DPYTHON_EXECUTABLE="${PYTHON_EXECUTABLE}" \
		-DBUILD_TESTS=OFF \
		-DCMAKE_CXX_FLAGS=-w \
		-DCMAKE_BUILD_TYPE=Release \
		-DMODULES="Core;Gui;Widgets" \
		../../sources/pyside2
	make -C "${PYSIDE_SRC_DIR}/build/pyside2" -j${BUILD_THREADS} > /dev/null
	make -C "${PYSIDE_SRC_DIR}/build/pyside2" install > /dev/null

.PHONY: clean-pyside
clean-pyside:
	rm -f "${PYSIDE_SRC_FILE}"
	rm -rf "${PYSIDE_SRC_DIR}"

.PHONY: distclean-pyside
distclean-pyside: clean-pyside
	rm -rf "${PYSIDE_PREFIX}"

# Package

${PACKAGE_FILE}: python qt pyside
	ls
	tar -czf "${PACKAGE_FILE}" qt python pyside

.PHONY: pkg
pkg: ${PACKAGE_FILE}

.PHONY: distclean-pkg
distclean-pkg:
	rm -f "${PACKAGE_FILE}"

