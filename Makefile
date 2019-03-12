
ROOT_DIR=${CURDIR}

PLATFORMS_SUPPORTED=win linux macos
ifeq (${OS},Windows_NT)
  PLATFORM:=win
else
  UNAME_S=${shell uname -s}
  ifeq (${UNAME_S},Linux)
    PLATFORM:=linux
  endif
  ifeq (${UNAME_S},Darwin)
    PLATFORM:=macos
  endif
endif
ifeq ($(filter ${PLATFORM},${PLATFORMS_SUPPORTED}),)
  ${error Platform not detected or unsupported.}
endif

PKG_FILES=pyside relocate.sh env.sh

ifeq (${PYTHON_WINDOWS},)
PYTHON_SRC_FILE=Python-3.6.4.tar.xz
PYTHON_SRC_MD5=1325134dd525b4a2c3272a1a0214dd54
PYTHON_SRC_URL=https://www.python.org/ftp/python/3.6.4/Python-3.6.4.tar.xz
PYTHON_SRC_DIR=Python-3.6.4
PYTHON_DEPS=python
PKG_FILES+=python
ifeq (${PLATFORM},macos)
  PYTHON_FRAMEWORK=${ROOT_DIR}/python/Python.framework
  PYTHON_PREFIX=${PYTHON_FRAMEWORK}/Versions/Current
else
  PYTHON_PREFIX:=${ROOT_DIR}/python
endif
${PYTHON_SRC_DIR}_target=PYTHON_SRC
PYTHON_LIBRARY=${PYTHON_PREFIX}/lib/libpython3.so
PYTHON_INCLUDE_DIR=${PYTHON_PREFIX}/include/python3.6m
PYTHON_EXECUTABLE=${PYTHON_PREFIX}/bin/python3
else
PYTHON_PREFIX=${PYTHON_WINDOWS}
PYTHON_LIBRARY=${PYTHON_WINDOWS}/libs/python3.lib
PYTHON_INCLUDE_DIR=${PYTHON_WINDOWS}/include
PYTHON_EXECUTABLE=${PYTHON_WINDOWS}/python.exe
PYTHON_DEPS=
endif


PATCHELF_SRC_FILE=patchelf-0.9.tar.bz2
PATCHELF_SRC_MD5=d02687629c7e1698a486a93a0d607947
PATCHELF_SRC_URL=https://nixos.org/releases/patchelf/patchelf-0.9/patchelf-0.9.tar.bz2
PATCHELF_SRC_DIR=patchelf-0.9
PATCHELF_EXECUTABLE=${PATCHELF_SRC_DIR}/src/patchelf
${PATCHELF_SRC_DIR}_target=PATCHELF_SRC

#QT_SRC_FILE=qt-everywhere-src-5.12.1.tar.xz
#QT_SRC_MD5=6a37466c8c40e87d4a19c3f286ec2542
#QT_SRC_URL=https://download.qt.io/official_releases/qt/5.12/5.12.1/single/qt-everywhere-src-5.12.1.tar.xz

ifeq (${QT_PREFIX},)
QT_BIN_FILE=cutter-deps-qt.tar.gz
QT_BIN_URL=https://github.com/radareorg/cutter-deps-qt/releases/download/v7/cutter-deps-qt-${PLATFORM}.tar.gz
QT_BIN_MD5_linux=c262bc39d9d07c75c6e8c42147e46760
QT_BIN_MD5_macos=ce6fb691b82dabf84a4bbbb4da780afd
QT_BIN_MD5_win=TODO
QT_BIN_MD5=${QT_BIN_MD5_${PLATFORM}}
QT_BIN_DIR=qt
QT_PREFIX:=${ROOT_DIR}/${QT_BIN_DIR}
${QT_BIN_DIR}_target=QT_BIN
QT_DEPS=qt
PKG_FILES+=qt
QT_OPENGL_ENABLED=0
else
QT_OPENGL_ENABLED:=1
QT_DEPS=
endif

PYSIDE_SRC_FILE=pyside-setup-everywhere-src-5.12.1.tar.xz
PYSIDE_SRC_MD5=c247fc1de38929d81aedd1c93d629d9e
PYSIDE_SRC_URL=https://download.qt.io/official_releases/QtForPython/pyside2/PySide2-5.12.1-src/pyside-setup-everywhere-src-5.12.1.tar.xz
PYSIDE_SRC_DIR=pyside-setup-everywhere-src-5.12.1
#PYSIDE_SRC_DIR=pyside-src
#PYSIDE_SRC_GIT=https://code.qt.io/pyside/pyside-setup.git
#PYSIDE_SRC_GIT_COMMIT=7a7952fc2e0809ef7f12a726376cec457897c364
PYSIDE_PREFIX=${ROOT_DIR}/pyside

PACKAGE_FILE=cutter-deps-${PLATFORM}.tar.gz

BUILD_THREADS=4

ifeq (${PLATFORM},linux)
  LLVM_LIBDIR=$(shell llvm-config --libdir)
  export LD_LIBRARY_PATH := ${PYTHON_PREFIX}/lib:${QT_PREFIX}/lib:${LLVM_LIBDIR}:${LD_LIBRARY_PATH}
endif
ifeq (${PLATFORM},macos)
  LLVM_LIBDIR=$(shell llvm-config --libdir)
  export DYLD_LIBRARY_PATH := ${PYTHON_PREFIX}/lib:${QT_PREFIX}/lib:${LLVM_LIBDIR}:${DYLD_LIBRARY_PATH}
  export DYLD_FRAMEWORK_PATH := ${PYTHON_PREFIX}/lib:${QT_PREFIX}/lib:${LLVM_LIBDIR}:${DYLD_FRAMEWORK_PATH}
endif

ifeq (${PLATFORM},linux)
  PATCHELF_TARGET=${PATCHELF_EXECUTABLE}
  PATCHELF_TARGET_CLEAN=clean-patchelf
  PATCHELF_TARGET_DISTCLEAN=distclean-patchelf
else#
  PATCHELF_TARGET=
  PATCHELF_TARGET_CLEAN=
  PATCHELF_TARGET_DISTCLEAN=
endif

all: ${PYTHON_DEPS} ${QT_DEPS} pyside relocate.sh pkg

.PHONY: clean
clean: clean-python clean-qt clean-pyside clean-relocate.sh clean-env.sh ${PATCHELF_TARGET_CLEAN}

.PHONY: distclean
distclean: distclean-python distclean-qt distclean-pyside distclean-pkg clean-relocate.sh clean-env.sh ${PATCHELF_TARGET_DISTCLEAN}

# Download Targets

ifeq (${PLATFORM},macos)
  define check_md5
	@echo "Checking MD5 for $1"
        @if [ "`md5 -r \"$1\"`" != "$2 $1" ]; then \
                echo "MD5 mismatch for file $1"; \
                exit 1; \
        else \
                echo "$1 OK"; \
        fi
  endef
else
  define check_md5
        echo "$2 $1" | md5sum -c -
  endef
endif

define download_extract
	curl -L "$1" -o "$2"
	${call check_md5,$2,$3}
	tar -xf "$2"
endef

${PYTHON_SRC_DIR} ${QT_BIN_DIR} ${PATCHELF_SRC_DIR}:
	@echo ""
	@echo "#########################"
	@echo "# Downloading ${$@_target}"
	@echo "#########################"
	@echo ""
	$(call download_extract,${${$@_target}_URL},${${$@_target}_FILE},${${$@_target}_MD5})


# Python

ifeq (${PLATFORM},macos)
define macos_fix_python_lib_path
	ORIGINAL_PERMS=$$(stat -f "%OLp" "$1") && \
	chmod +w "$1" && \
	install_name_tool -change `otool -L "$1" | sed -n "s/^[[:blank:]]*\([^[:blank:]]*Python\) (.*$$/\1/p"` "$2" "$1" && \
	chmod "$$ORIGINAL_PERMS" "$1"
endef
endif

python: ${PYTHON_SRC_DIR} ${PATCHELF_TARGET}
	@echo ""
	@echo "#########################"
	@echo "# Building Python       #"
	@echo "#########################"
	@echo ""

ifeq (${PLATFORM},macos)
	cd "${PYTHON_SRC_DIR}" && \
		CPPFLAGS="-I$(shell brew --prefix openssl)/include" \
		 LDFLAGS="-L$(shell brew --prefix openssl)/lib" \
		./configure --enable-framework="${ROOT_DIR}/python"
	# Patch for https://github.com/radareorg/cutter/issues/424
	sed -i ".original" "s/#define HAVE_GETENTROPY 1/#define HAVE_GETENTROPY 0/" "${PYTHON_SRC_DIR}/pyconfig.h"
else
	cd "${PYTHON_SRC_DIR}" && ./configure --enable-shared --prefix="${PYTHON_PREFIX}"
endif

	make -C "${PYTHON_SRC_DIR}" -j${BUILD_THREADS} > /dev/null

ifeq (${PLATFORM},macos)
	make -C "${PYTHON_SRC_DIR}" frameworkinstallframework > /dev/null
else
	make -C "${PYTHON_SRC_DIR}" install > /dev/null
endif

ifeq (${PLATFORM},linux)
	for lib in "${PYTHON_PREFIX}/lib/python3.6/lib-dynload"/*.so ; do \
		echo "  patching $$lib" && \
		"${PATCHELF_EXECUTABLE}" --set-rpath '$$ORIGIN/../..' "$$lib" || exit 1 ; \
	done
endif

ifeq (${PLATFORM},macos)
	${call macos_fix_python_lib_path,${PYTHON_PREFIX}/bin/python3,@executable_path/../Python}
	${call macos_fix_python_lib_path,${PYTHON_PREFIX}/Python,@executable_path/Python}
	${call macos_fix_python_lib_path,${PYTHON_PREFIX}/Resources/Python.app/Contents/MacOS/Python,@executable_path/../../../../Python}
endif


	
.PHONY: clean-python
clean-python:
	rm -f "${PYTHON_SRC_FILE}"
	rm -rf "${PYTHON_SRC_DIR}"

.PHONY: distclean-python
distclean-python: clean-python
	rm -rf python


# patchelf

ifeq (${PLATFORM},linux)

${PATCHELF_EXECUTABLE}: ${PATCHELF_SRC_DIR}
	cd "${PATCHELF_SRC_DIR}" && ./configure
	make -C "${PATCHELF_SRC_DIR}" -j${BUILD_THREADS} > /dev/null

.PHONY: patchelf
patchelf: ${PATCHELF_EXECUTABLE}

.PHONY: clean-patchelf
clean-patchelf:
	rm -f "${PATCHELF_SRC_FILE}"
	rm -rf "${PATCHELF_SRC_DIR}"

distclean-patchelf: clean-patchelf

endif

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

	$(call download_extract,${PYSIDE_SRC_URL},${PYSIDE_SRC_FILE},${PYSIDE_SRC_MD5})
	#git clone "${PYSIDE_SRC_GIT}" "${PYSIDE_SRC_DIR}"
	#cd "${PYSIDE_SRC_DIR}" && git checkout "${PYSIDE_SRC_GIT_COMMIT}"
	
	# Patch needed, so the PySide2 CMakeLists.txt doesn't search for Qt5UiTools and other stuff,
	# which would mess up finding the actual modules later.
	patch "${PYSIDE_SRC_DIR}/sources/pyside2/CMakeLists.txt" patch/pyside-5.12.1/CMakeLists.txt.patch
	echo "" > "${PYSIDE_SRC_DIR}/sources/pyside2/cmake/Macros/FindQt5Extra.cmake"

	# Patch to prevent complete overriding of LD_LIBRARY_PATH
	#patch "${PYSIDE_SRC_DIR}/sources/pyside2/cmake/Macros/PySideModules.cmake" patch/pyside2-PySideModules.cmake.patch

ifeq (${QT_OPENGL_ENABLED},1)
	# Patches to remove OpenGL-related source files.
	patch "${PYSIDE_SRC_DIR}/sources/pyside2/PySide2/QtGui/CMakeLists.txt" patch/pyside-5.12.1/QtGui-CMakeLists.txt.patch
	patch "${PYSIDE_SRC_DIR}/sources/pyside2/PySide2/QtWidgets/CMakeLists.txt" patch/pyside-5.12.1/QtWidgets-CMakeLists.txt.patch
endif

pyside: ${PYTHON_DEPS} ${QT_DEPS} ${PYSIDE_SRC_DIR}
	@echo ""
	@echo "#########################"
	@echo "# Building Shiboken2    #"
	@echo "#########################"
	@echo ""

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

ifeq (${PLATFORM},macos)
	install_name_tool -add_rpath @executable_path/../../qt/lib "${PYSIDE_PREFIX}/bin/shiboken2"
endif

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
	make -C "${PYSIDE_SRC_DIR}/build/pyside2" -j${BUILD_THREADS}
	make -C "${PYSIDE_SRC_DIR}/build/pyside2" install

.PHONY: clean-pyside
clean-pyside:
	rm -f "${PYSIDE_SRC_FILE}"
	rm -rf "${PYSIDE_SRC_DIR}"

.PHONY: distclean-pyside
distclean-pyside: clean-pyside
	rm -rf "${PYSIDE_PREFIX}"

# Relocation script

relocate.sh: relocate.sh.in
	printf "#!/bin/bash\n\nORIGINAL_ROOT=\"${ROOT_DIR}\"\nPLATFORM=${PLATFORM}" > relocate.sh
	cat relocate.sh.in >> relocate.sh
	chmod +x relocate.sh

.PHONY: clean-relocate.sh
clean-relocate.sh:
	rm -f relocate.sh

# Environment script

env.sh: env.sh.in
	printf "#!/bin/bash\n\nPLATFORM=${PLATFORM}\n" > env.sh
	cat env.sh.in >> env.sh
	chmod +x env.sh

.PHONY: clean-env.sh
clean-env.sh:
	rm -f env.sh

# Package

${PACKAGE_FILE}: ${PKG_FILES}
	tar -czf "${PACKAGE_FILE}" ${PKG_FILES}

.PHONY: pkg
pkg: ${PACKAGE_FILE}

.PHONY: distclean-pkg
distclean-pkg:
	rm -f "${PACKAGE_FILE}"


