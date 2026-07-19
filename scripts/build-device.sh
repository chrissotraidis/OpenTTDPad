#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
host_build="$repo_root/build/host-tools"
device_prefix="$repo_root/build/deps/prefix-device"
sdl_build="$repo_root/build/deps/sdl2-device"
xz_build="$repo_root/build/deps/xz-device"
png_build="$repo_root/build/deps/libpng-device"
freetype_build="$repo_root/build/deps/freetype-device"
harfbuzz_build="$repo_root/build/deps/harfbuzz-device"
curl_build="$repo_root/build/deps/curl-device"
mbedtls_build="$repo_root/build/deps/mbedtls-device"
device_build="$repo_root/build/ios-device"

cmake -S "$repo_root/engine" -B "$host_build" -G Ninja \
    -DOPTION_TOOLS_ONLY=ON -DCMAKE_BUILD_TYPE=Release
cmake --build "$host_build" --target tools --parallel 8

cmake -S "$repo_root/ref/SDL2" -B "$sdl_build" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$device_prefix" \
    -DSDL_SHARED=OFF -DSDL_STATIC=ON -DSDL_TEST=OFF
cmake --build "$sdl_build" --target install --parallel 8

cmake -S "$repo_root/ref/xz" -B "$xz_build" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$device_prefix" \
    -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DXZ_NLS=OFF \
    -DXZ_TOOL_XZ=OFF -DXZ_TOOL_XZDEC=OFF -DXZ_TOOL_LZMADEC=OFF \
    -DXZ_TOOL_LZMAINFO=OFF
cmake --build "$xz_build" --target install --parallel 8

cmake -S "$repo_root/ref/libpng" -B "$png_build" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$device_prefix" \
    -DPNG_SHARED=OFF -DPNG_STATIC=ON -DPNG_FRAMEWORK=OFF \
    -DPNG_TESTS=OFF -DPNG_TOOLS=OFF
cmake --build "$png_build" --target install --parallel 8

cmake -S "$repo_root/ref/freetype" -B "$freetype_build" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$device_prefix" \
    -DFT_DISABLE_BROTLI=ON -DFT_DISABLE_BZIP2=ON \
    -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_PNG=ON -DFT_DISABLE_ZLIB=ON
cmake --build "$freetype_build" --target install --parallel 8

cmake -S "$repo_root/ref/harfbuzz" -B "$harfbuzz_build" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$device_prefix" \
    -DFREETYPE_LIBRARY="$device_prefix/lib/libfreetype.a" \
    -DFREETYPE_INCLUDE_DIRS="$device_prefix/include/freetype2" \
    -DFREETYPE_INCLUDE_DIR_ft2build="$device_prefix/include/freetype2" \
    -DFREETYPE_INCLUDE_DIR_freetype2="$device_prefix/include/freetype2" \
    -DHB_HAVE_FREETYPE=ON -DHB_HAVE_CORETEXT=OFF -DHB_HAVE_ICU=OFF \
    -DHB_BUILD_SUBSET=OFF -DHB_BUILD_UTILS=OFF -DHB_BUILD_RASTER=OFF \
    -DHB_BUILD_VECTOR=OFF -DHB_BUILD_GPU=OFF
cmake --build "$harfbuzz_build" --target install --parallel 8

cmake -S "$repo_root/ref/mbedtls" -B "$mbedtls_build" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$device_prefix" \
    -DENABLE_PROGRAMS=OFF -DENABLE_TESTING=OFF \
    -DUSE_SHARED_MBEDTLS_LIBRARY=OFF -DUSE_STATIC_MBEDTLS_LIBRARY=ON
cmake --build "$mbedtls_build" --target install --parallel 8

cmake -S "$repo_root/ref/curl" -B "$curl_build" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$device_prefix" \
    -DCMAKE_PREFIX_PATH="$device_prefix" \
    -DBUILD_SHARED_LIBS=OFF -DBUILD_CURL_EXE=OFF -DBUILD_TESTING=OFF \
    -DCURL_USE_OPENSSL=OFF -DCURL_USE_MBEDTLS=ON \
    -DMBEDTLS_INCLUDE_DIR="$device_prefix/include" \
    -DMBEDTLS_LIBRARY="$device_prefix/lib/libmbedtls.a" \
    -DMBEDX509_LIBRARY="$device_prefix/lib/libmbedx509.a" \
    -DMBEDCRYPTO_LIBRARY="$device_prefix/lib/libmbedcrypto.a" \
    -DCURL_USE_LIBPSL=OFF -DCURL_USE_LIBSSH2=OFF \
    -DCURL_DISABLE_LDAP=ON -DCURL_DISABLE_LDAPS=ON \
    -DCURL_DISABLE_DICT=ON -DCURL_DISABLE_FILE=ON -DCURL_DISABLE_FTP=ON \
    -DCURL_DISABLE_GOPHER=ON -DCURL_DISABLE_IMAP=ON -DCURL_DISABLE_MQTT=ON \
    -DCURL_DISABLE_POP3=ON -DCURL_DISABLE_RTSP=ON -DCURL_DISABLE_SMB=ON \
    -DCURL_DISABLE_SMTP=ON -DCURL_DISABLE_TELNET=ON -DCURL_DISABLE_TFTP=ON
cmake --build "$curl_build" --target install --parallel 8

cmake -S "$repo_root/engine" -B "$device_build" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DSDL2_DIR="$device_prefix/lib/cmake/SDL2" \
    -DHOST_BINARY_DIR="$host_build" \
    -DLIBLZMA_INCLUDE_DIR="$device_prefix/include" \
    -DLIBLZMA_LIBRARY="$device_prefix/lib/liblzma.a" \
    -DLIBLZMA_LIBRARY_RELEASE="$device_prefix/lib/liblzma.a" \
    -DPNG_PNG_INCLUDE_DIR="$device_prefix/include" \
    -DPNG_LIBRARY="$device_prefix/lib/libpng16.a" \
    -DFREETYPE_LIBRARY="$device_prefix/lib/libfreetype.a" \
    -DFREETYPE_LIBRARY_RELEASE="$device_prefix/lib/libfreetype.a" \
    -DFREETYPE_INCLUDE_DIR_ft2build="$device_prefix/include/freetype2" \
    -DFREETYPE_INCLUDE_DIR_freetype2="$device_prefix/include/freetype2" \
    -DHarfbuzz_LIBRARY="$device_prefix/lib/libharfbuzz.a" \
    -DHarfbuzz_INCLUDE_DIR="$device_prefix/include/harfbuzz" \
    -DCURL_INCLUDE_DIR="$device_prefix/include" \
    -DCURL_LIBRARY="$device_prefix/lib/libcurl.a" \
    -DOPENTTDPAD_MBEDTLS_LIBRARIES="$device_prefix/lib/libmbedtls.a;$device_prefix/lib/libmbedx509.a;$device_prefix/lib/libmbedcrypto.a" \
    -DOPTION_USE_ASSERTS=ON
cmake --build "$device_build" --target openttd --parallel 8

"$repo_root/scripts/package-device.sh"

printf '%s\n' "Unsigned arm64 device app built at $device_build/openttd.app"
