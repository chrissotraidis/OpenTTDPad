#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
host_build="$repo_root/build/host-tools"
sdl_build="$repo_root/build/deps/sdl2-sim"
xz_build="$repo_root/build/deps/xz-sim"
png_build="$repo_root/build/deps/libpng-sim"
curl_build="$repo_root/build/deps/curl-sim"
mbedtls_build="$repo_root/build/deps/mbedtls-sim"
sdl_prefix="$repo_root/build/deps/prefix-sim"
ios_build="$repo_root/build/ios-sim"

cmake -S "$repo_root/engine" -B "$host_build" -G Ninja \
    -DOPTION_TOOLS_ONLY=ON \
    -DCMAKE_BUILD_TYPE=Release
cmake --build "$host_build" --target tools --parallel 8

cmake -S "$repo_root/ref/SDL2" -B "$sdl_build" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$sdl_prefix" \
    -DSDL_SHARED=OFF \
    -DSDL_STATIC=ON \
    -DSDL_TEST=OFF
cmake --build "$sdl_build" --target install --parallel 8

cmake -S "$repo_root/ref/xz" -B "$xz_build" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$sdl_prefix" \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_TESTING=OFF \
    -DXZ_NLS=OFF \
    -DXZ_TOOL_XZ=OFF \
    -DXZ_TOOL_XZDEC=OFF \
    -DXZ_TOOL_LZMADEC=OFF \
    -DXZ_TOOL_LZMAINFO=OFF
cmake --build "$xz_build" --target install --parallel 8

cmake -S "$repo_root/ref/libpng" -B "$png_build" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$sdl_prefix" \
    -DPNG_SHARED=OFF \
    -DPNG_STATIC=ON \
    -DPNG_FRAMEWORK=OFF \
    -DPNG_TESTS=OFF \
    -DPNG_TOOLS=OFF
cmake --build "$png_build" --target install --parallel 8

cmake -S "$repo_root/ref/mbedtls" -B "$mbedtls_build" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$sdl_prefix" \
    -DENABLE_PROGRAMS=OFF \
    -DENABLE_TESTING=OFF \
    -DUSE_SHARED_MBEDTLS_LIBRARY=OFF \
    -DUSE_STATIC_MBEDTLS_LIBRARY=ON
cmake --build "$mbedtls_build" --target install --parallel 8

cmake -S "$repo_root/ref/curl" -B "$curl_build" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$sdl_prefix" \
    -DCMAKE_PREFIX_PATH="$sdl_prefix" \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_CURL_EXE=OFF \
    -DBUILD_TESTING=OFF \
    -DCURL_USE_OPENSSL=OFF \
    -DCURL_USE_MBEDTLS=ON \
    -DMBEDTLS_INCLUDE_DIR="$sdl_prefix/include" \
    -DMBEDTLS_LIBRARY="$sdl_prefix/lib/libmbedtls.a" \
    -DMBEDX509_LIBRARY="$sdl_prefix/lib/libmbedx509.a" \
    -DMBEDCRYPTO_LIBRARY="$sdl_prefix/lib/libmbedcrypto.a" \
    -DCURL_USE_LIBPSL=OFF \
    -DCURL_USE_LIBSSH2=OFF \
    -DCURL_DISABLE_LDAP=ON \
    -DCURL_DISABLE_LDAPS=ON \
    -DCURL_DISABLE_DICT=ON \
    -DCURL_DISABLE_FILE=ON \
    -DCURL_DISABLE_FTP=ON \
    -DCURL_DISABLE_GOPHER=ON \
    -DCURL_DISABLE_IMAP=ON \
    -DCURL_DISABLE_MQTT=ON \
    -DCURL_DISABLE_POP3=ON \
    -DCURL_DISABLE_RTSP=ON \
    -DCURL_DISABLE_SMB=ON \
    -DCURL_DISABLE_SMTP=ON \
    -DCURL_DISABLE_TELNET=ON \
    -DCURL_DISABLE_TFTP=ON
cmake --build "$curl_build" --target install --parallel 8

cmake -S "$repo_root/engine" -B "$ios_build" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DSDL2_DIR="$sdl_prefix/lib/cmake/SDL2" \
    -DHOST_BINARY_DIR="$host_build" \
    -DLIBLZMA_INCLUDE_DIR="$sdl_prefix/include" \
    -DLIBLZMA_LIBRARY="$sdl_prefix/lib/liblzma.a" \
    -DLIBLZMA_LIBRARY_RELEASE="$sdl_prefix/lib/liblzma.a" \
    -DPNG_PNG_INCLUDE_DIR="$sdl_prefix/include" \
    -DPNG_LIBRARY="$sdl_prefix/lib/libpng16.a" \
    -DCURL_INCLUDE_DIR="$sdl_prefix/include" \
    -DCURL_LIBRARY="$sdl_prefix/lib/libcurl.a" \
    -DOPENTTDPAD_MBEDTLS_LIBRARIES="$sdl_prefix/lib/libmbedtls.a;$sdl_prefix/lib/libmbedx509.a;$sdl_prefix/lib/libmbedcrypto.a" \
    -DOPTION_USE_ASSERTS=ON
cmake --build "$ios_build" --target openttd --parallel 8

"$repo_root/scripts/package-simulator.sh"
