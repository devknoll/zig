#!/bin/sh

# Requires cmake

set -x
set -e

ARCH="$(uname -m)"
TARGET="$ARCH-linux-musl"
MCPU="baseline"
PREFIX="/usr/lib/llvm-19/"

mkdir build-debug
cd build-debug

sudo apt-get install libllvm19 llvm-19-dev llvm-19 lld-19 liblld-19-dev libclang-19-dev libpolly-19-dev libc++-19-dev libc++abi-19-dev

export LDFLAGS="$LDFLAGS -L/usr/lib/llvm-19/lib"
export CPPFLAGS="$CPPFLAGS -I/usr/lib/llvm-19/include"

cmake .. \
  -DCMAKE_PREFIX_PATH="/usr/lib/llvm-19/lib/" \
  -DCMAKE_INSTALL_PREFIX="stage3-debug" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DZIG_SHARED_LLVM=ON \
  -DZIG_NO_LIB=ON

make install

# simultaneously test building self-hosted without LLVM and with 32-bit arm
stage3-debug/bin/zig build \
  -Dtarget=arm-linux-musleabihf \
  -Dno-lib

# No -fqemu and -fwasmtime here as they're covered by the x86_64-linux scripts.
stage3-debug/bin/zig build test docs \
  --maxrss 24696061952 \
  -Dstatic-llvm \
  -Dtarget=native-native-musl \
  --search-prefix "$PREFIX" \
  --zig-lib-dir "$PWD/../lib" \
  -Denable-superhtml

# Ensure that updating the wasm binary from this commit will result in a viable build.
stage3-debug/bin/zig build update-zig1

mkdir ../build-new
cd ../build-new

export CC="$ZIG cc -target $TARGET -mcpu=$MCPU"
export CXX="$ZIG c++ -target $TARGET -mcpu=$MCPU"

cmake .. \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DZIG_TARGET_TRIPLE="$TARGET" \
  -DZIG_TARGET_MCPU="$MCPU" \
  -DZIG_STATIC=ON \
  -DZIG_NO_LIB=ON \
  -GNinja

unset CC
unset CXX

ninja install

stage3/bin/zig test ../test/behavior.zig
stage3/bin/zig build -p stage4 \
  -Dstatic-llvm \
  -Dtarget=native-native-musl \
  -Dno-lib \
  --search-prefix "$PREFIX" \
  --zig-lib-dir "$PWD/../lib"
stage4/bin/zig test ../test/behavior.zig
