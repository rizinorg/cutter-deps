
ROOT_DIR=${CURDIR}

PLATFORMS_SUPPORTED=win linux macos
ARCH:=x86_64
ifeq (${OS},Windows_NT)
  PLATFORM:=win
else
  UNAME_S=${shell uname -s}
  ifeq (${UNAME_S},Linux)
    PLATFORM:=linux
  endif
  ifeq (${UNAME_S},Darwin)
    PLATFORM:=macos
    ARCH:=${shell uname -m}
  endif
endif
ifeq ($(filter ${PLATFORM},${PLATFORMS_SUPPORTED}),)
  ${error Platform not detected or unsupported.}
endif

PKG_FILES=pyside

ifeq (${PYTHON_WINDOWS},)
PYTHON_VERSION=3.12.4
PYTHON_VERSION_MAJOR_MINOR=3.12
PYTHON_SRC_FILE=Python-${PYTHON_VERSION}.tar.xz
PYTHON_SRC_SHA256=f6d419a6d8743ab26700801b4908d26d97e8b986e14f95de31b32de2b0e79554

PYTHON_SRC_URL=https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz
PYTHON_SRC_DIR=Python-${PYTHON_VERSION}
PYTHON_DEPS=python
PKG_FILES+=python
ifeq (${PLATFORM},macos)
  PYTHON_FRAMWORK_DIR=${ROOT_DIR}/python/Library/Frameworks
  PYTHON_FRAMEWORK=${PYTHON_FRAMWORK_DIR}/Python.framework
  PYTHON_PREFIX=${PYTHON_FRAMEWORK}/Versions/Current
else
  PYTHON_PREFIX:=${ROOT_DIR}/python
endif
${PYTHON_SRC_DIR}_target=PYTHON_SRC
PYTHON_LIBRARY=${PYTHON_PREFIX}/lib/libpython3.so
PYTHON_INCLUDE_DIR=${PYTHON_PREFIX}/include/python${PYTHON_VERSION_MAJOR_MINOR}
PYTHON_EXECUTABLE=${PYTHON_PREFIX}/bin/python3
else
PYTHON_PREFIX=${PYTHON_WINDOWS}
PYTHON_LIBRARY=${PYTHON_WINDOWS}/libs/python3.lib
PYTHON_INCLUDE_DIR=${PYTHON_WINDOWS}/include
PYTHON_EXECUTABLE=${PYTHON_WINDOWS}/python.exe
PYTHON_DEPS=
endif


PATCHELF_SRC_FILE=patchelf-0.9.tar.bz2
PATCHELF_SRC_SHA256=a0f65c1ba148890e9f2f7823f4bedf7ecad5417772f64f994004f59a39014f83
PATCHELF_SRC_URL=https://nixos.org/releases/patchelf/patchelf-0.9/patchelf-0.9.tar.bz2
PATCHELF_SRC_DIR=patchelf-0.9
PATCHELF_EXECUTABLE=${PATCHELF_SRC_DIR}/src/patchelf
${PATCHELF_SRC_DIR}_target=PATCHELF_SRC

ifeq (${QT_PREFIX},)
QT_BIN_FILE=cutter-deps-qt-${PLATFORM}-${ARCH}.tar.gz
PACKAGE_FILE=cutter-deps-${PLATFORM}-${ARCH}.tar.gz
QT_BIN_URL=https://github.com/rizinorg/cutter-deps-qt/releases/download/v14/${QT_BIN_FILE}
QT_BIN_SHA256_linux_x86_64=2e7f6af35b2aab46b5fcd637b2035527ab378c3dc209bcbb84cd82e6cea120fb
QT_BIN_SHA256_macos_arm64=80cb4faf70dc4cca9c745ecaf6a924fb6b6ed55a3dd0ae45071b10c53bd4a294
QT_BIN_SHA256_macos_x86_64=7d76c9630020ab52e97e43fbb251c3c8ff9669c1b631d88a2594cd6279cfe1ca
QT_BIN_SHA256_win_x86_64=61e5023363d13eabf8c62e86c6dd6f0cb80a001bb4e51d0e1348387b13857ca3
QT_BIN_SHA256=${QT_BIN_SHA256_${PLATFORM}_${ARCH}}
QT_BIN_DIR=qt
QT_PREFIX:=${ROOT_DIR}/${QT_BIN_DIR}
${QT_BIN_DIR}_target=QT_BIN
QT_DEPS=qt
PKG_FILES+=qt
QT_OPENGL_ENABLED=1
else
QT_OPENGL_ENABLED:=1
QT_DEPS=
endif

QT_VERSION=6.7.2
ifeq (${PLATFORM},win)
  # Windows has some issues with symlinks in the tarball
  PYSIDE_SRC_FILE=pyside-setup-everywhere-src-${QT_VERSION}.zip
  PYSIDE_SRC_SHA256=cde443ce209787e0008a2c510d9d390423ea8876083b356d8148272c1234c102
else
  PYSIDE_SRC_FILE=pyside-setup-everywhere-src-${QT_VERSION}.tar.xz
  PYSIDE_SRC_SHA256=3a2b0d0d6e78c9aa5ddc7f06ca4b6f11a3fe14560baeb148eea53b5d98e368c7
endif
PYSIDE_SRC_URL=https://download.qt.io/official_releases/QtForPython/pyside6/PySide6-${QT_VERSION}-src/${PYSIDE_SRC_FILE}
PYSIDE_SRC_DIR=pyside-setup-everywhere-src-${QT_VERSION}
PYSIDE_PREFIX=${ROOT_DIR}/pyside

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
else
  PATCHELF_TARGET=
  PATCHELF_TARGET_CLEAN=
  PATCHELF_TARGET_DISTCLEAN=
endif

ifneq (${PLATFORM},win)
  PKG_FILES += env.sh relocate.sh
endif

all: pkg 

.PHONY: clean
clean: clean-python clean-qt clean-pyside clean-relocate.sh clean-env.sh ${PATCHELF_TARGET_CLEAN}

.PHONY: distclean
distclean: distclean-python distclean-qt distclean-pyside distclean-pkg clean-relocate.sh clean-env.sh ${PATCHELF_TARGET_DISTCLEAN}

# Download Targets

define check_sha256
	echo "$2  $1" | shasum -a 256 -c -
endef

define download_extract
	curl -L "$1" -o "$2"
	${call check_sha256,$2,$3}
	$(if $(patsubst %.zip,,$(lastword $2)),tar --no-same-owner -xf,7z x -bsp1) "$2"
endef

${PYTHON_SRC_DIR} ${QT_BIN_DIR} ${PATCHELF_SRC_DIR}:
	@echo ""
	@echo "#########################"
	@echo "# Downloading ${$@_target}"
	@echo "#########################"
	@echo ""
	$(call download_extract,${${$@_target}_URL},${${$@_target}_FILE},${${$@_target}_SHA256})


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
	@echo "platform ${PLATFORM}"

ifeq (${PLATFORM}-${ARCH},macos-x86_64)
	cd "${PYTHON_SRC_DIR}" && \
		CPPFLAGS="${CPPFLAGS} -I$(shell brew --prefix openssl)/include" \
		LDFLAGS="${LDFLAGS} -L$(shell brew --prefix openssl)/lib" \
		./configure --enable-framework="${PYTHON_FRAMWORK_DIR}" --prefix="${ROOT_DIR}/python_prefix_tmp"
	# Patch for https://github.com/rizinorg/cutter/issues/424
	sed -i ".original" "s/#define HAVE_GETENTROPY 1/#define HAVE_GETENTROPY 0/" "${PYTHON_SRC_DIR}/pyconfig.h"
else ifeq (${PLATFORM},macos)
	cd "${PYTHON_SRC_DIR}" && \
		./configure --enable-framework="${PYTHON_FRAMWORK_DIR}" --prefix="${ROOT_DIR}/python_prefix_tmp"
else
	cd "${PYTHON_SRC_DIR}" && ./configure --enable-shared --prefix="${PYTHON_PREFIX}"
endif

	make -C "${PYTHON_SRC_DIR}" -j > /dev/null

ifeq (${PLATFORM},macos)
	make -C "${PYTHON_SRC_DIR}" frameworkinstallframework
else
	make -C "${PYTHON_SRC_DIR}" install > /dev/null
endif

ifeq (${PLATFORM},linux)
	for lib in "${PYTHON_PREFIX}/lib/python${PYTHON_VERSION_MAJOR_MINOR}/lib-dynload"/*.so ; do \
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
	rm -rf python_prefix_tmp

.PHONY: distclean-python
distclean-python: clean-python
	rm -rf python


# patchelf

ifeq (${PLATFORM},linux)

${PATCHELF_EXECUTABLE}: ${PATCHELF_SRC_DIR}
	cd "${PATCHELF_SRC_DIR}" && ./configure
	make -C "${PATCHELF_SRC_DIR}" -j > /dev/null

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

# Shiboken + PySide

ifeq (${PLATFORM},win)
PLATFORM_CMAKE_ARGS=-G Ninja -DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl -DFORCE_LIMITED_API=yes
else
PLATFORM_CMAKE_ARGS=-DFORCE_LIMITED_API=no
endif

${PYSIDE_SRC_DIR}:
	@echo ""
	@echo "#########################"
	@echo "# Downloading PySide    #"
	@echo "#########################"
	@echo ""

	$(call download_extract,${PYSIDE_SRC_URL},${PYSIDE_SRC_FILE},${PYSIDE_SRC_SHA256})
	#git clone "${PYSIDE_SRC_GIT}" "${PYSIDE_SRC_DIR}"
	#cd "${PYSIDE_SRC_DIR}" && git checkout "${PYSIDE_SRC_GIT_COMMIT}"
	
	# Patch needed, so the PySide2 CMakeLists.txt doesn't search for Qt5UiTools and other stuff,
	# which would mess up finding the actual modules later.
	patch "${PYSIDE_SRC_DIR}/sources/pyside6/CMakeLists.txt" patch/pyside-5.15.2/CMakeLists.txt.patch


ifneq (${QT_OPENGL_ENABLED},1)
	# Patches to remove OpenGL-related source files.
	patch "${PYSIDE_SRC_DIR}/sources/pyside2/PySide2/QtGui/CMakeLists.txt" patch/pyside-5.12.1/QtGui-CMakeLists.txt.patch
	patch "${PYSIDE_SRC_DIR}/sources/pyside2/PySide2/QtWidgets/CMakeLists.txt" patch/pyside-5.12.1/QtWidgets-CMakeLists.txt.patch
endif

ifeq (${PLATFORM},win)
# automatic msys -> windows path conversion doesn't detect semicolon separated paths
# cmake uses ; on all platforms
EXTRA_CMAKE_PREFIX="${QT_PREFIX}:${PYSIDE_PREFIX}"
else
EXTRA_CMAKE_PREFIX="${QT_PREFIX};${PYSIDE_PREFIX}"
endif

pyside: ${PYTHON_DEPS} ${QT_DEPS} ${PYSIDE_SRC_DIR}
	@echo ""
	@echo "#########################"
	@echo "# Building Shiboken     #"
	@echo "#########################"
	@echo ""

	echo "$$LLVM_INSTALL_DIR"

	mkdir -p "${PYSIDE_SRC_DIR}/build/shiboken6"
	cd "${PYSIDE_SRC_DIR}/build/shiboken6" && cmake \
		${PLATFORM_CMAKE_ARGS} \
		-DCMAKE_PREFIX_PATH="${QT_PREFIX}" \
		-DCMAKE_INSTALL_PREFIX="${PYSIDE_PREFIX}" \
		-DUSE_PYTHON_VERSION=3 \
		-DPython_ROOT_DIR="${PYTHON_PREFIX}" \
		-DBUILD_TESTS=OFF \
		-DCMAKE_BUILD_TYPE=Release \
		../../sources/shiboken6

	cmake --build "${PYSIDE_SRC_DIR}/build/shiboken6" -j
	cmake --install "${PYSIDE_SRC_DIR}/build/shiboken6"
	@echo "shiboken compiled"

ifeq (${PLATFORM},macos)
	install_name_tool -add_rpath @executable_path/../../qt/lib "${PYSIDE_PREFIX}/bin/shiboken6"
ifeq (${ARCH},arm64)
	# Our arm64 builder has llvm-14 installed with MacPorts
	install_name_tool -add_rpath /opt/local/libexec/llvm-14/lib "${PYSIDE_PREFIX}/bin/shiboken6"
endif
endif

	@echo ""
	@echo "#########################"
	@echo "# Building PySide       #"
	@echo "#########################"
	@echo ""

	@echo ${EXTRA_CMAKE_PREFIX}

	mkdir -p "${PYSIDE_SRC_DIR}/build/pyside6"
	cd "${PYSIDE_SRC_DIR}/build/pyside6" && cmake \
		${PLATFORM_CMAKE_ARGS} \
		-DCMAKE_PREFIX_PATH=${EXTRA_CMAKE_PREFIX} \
		-DCMAKE_INSTALL_PREFIX="${PYSIDE_PREFIX}" \
		-DUSE_PYTHON_VERSION=3 \
		-DPython_ROOT_DIR="${PYTHON_PREFIX}" \
		-DBUILD_TESTS=OFF \
		-DCMAKE_CXX_FLAGS=-w \
		-DCMAKE_BUILD_TYPE=Release \
		-DMODULES="Core;Gui;Widgets" \
		../../sources/pyside6

ifeq (${PLATFORM},win)
	cmake --build "${PYSIDE_SRC_DIR}/build/pyside6"
	cmake --install "${PYSIDE_SRC_DIR}/build/pyside6"
	cp "${LLVM_INSTALL_DIR}/bin/libclang.dll" "${PYSIDE_PREFIX}/bin/"
else
	make -C "${PYSIDE_SRC_DIR}/build/pyside6" -j1
	make -C "${PYSIDE_SRC_DIR}/build/pyside6" install
endif

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
ifeq (${PLATFORM},macos)
	shasum -a 256 "${PACKAGE_FILE}"
else
	sha256sum "${PACKAGE_FILE}"
endif

.PHONY: pkg
pkg: ${PACKAGE_FILE}

.PHONY: distclean-pkg
distclean-pkg:
	rm -f "${PACKAGE_FILE}"


