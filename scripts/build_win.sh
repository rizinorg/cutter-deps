set -euo pipefail

LLVM_NAME=clang+llvm-18.1.5-x86_64-pc-windows-msvc
LLVM_ARCHIVE="$LLVM_NAME.tar.xz"
wget --progress=dot:giga https://github.com/llvm/llvm-project/releases/download/llvmorg-18.1.5/$LLVM_ARCHIVE
echo "7027f03bcab87d8a72fee35a82163b0730a9c92f5160373597de95010f722935  ./$LLVM_ARCHIVE" | sha256sum -c -
tar -xf $LLVM_ARCHIVE
export LLVM_INSTALL_DIR=$PWD/$LLVM_NAME
export CMAKE_PREFIX_PATH=$LLVM_INSTALL_DIR


# REMOVE any gcc installs (possibly provided by msys) from path, we are trying to do a MSVC based build
which cl
which gcc
export PATH=`echo $PATH | tr ":" "\n" | grep -v "mingw64" | grep -v "Strawberry" | tr "\n" ":"`
echo $PATH
which gcc || echo "No GCC in path, OK!"


make PLATFORM=win "PYTHON_WINDOWS=/C/hostedtoolcache/windows/Python/3.12.4/x64/"