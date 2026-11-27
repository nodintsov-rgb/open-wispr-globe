#!/bin/bash
set -euo pipefail

archive="${1:?Usage: bash scripts/build-whisper-runtime.sh whisper.cpp-v1.9.4.tar.gz output-directory}"
output="${2:?Missing output directory}"
version='1.9.4'
checksum='57e280cee375ab02425b806ad5146b99f6eb9357e3c2b31357c8a6af2e2e44ae'
printf '%s  %s\n' "$checksum" "$archive" | shasum -a 256 -c -
mkdir -p "$output"
output="$(cd "$output" && pwd)"
tar -xzf "$archive" -C "$output"
source_dir="$output/whisper.cpp-$version"

for arch in arm64 x86_64; do
    metal=OFF
    if [[ "$arch" == arm64 ]]; then
        metal=ON
    fi
    build_dir="$output/build-$arch"
    cmake -S "$source_dir" -B "$build_dir" \
        -DCMAKE_OSX_ARCHITECTURES="$arch" -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
        -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
        -DGGML_NATIVE=OFF -DGGML_OPENMP=OFF -DGGML_METAL="$metal" \
        -DGGML_METAL_EMBED_LIBRARY="$metal" -DWHISPER_COREML=OFF \
        -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_SERVER=OFF \
        -DWHISPER_BUILD_EXAMPLES=ON -DWHISPER_SDL2=OFF -DWHISPER_CURL=OFF
    cmake --build "$build_dir" --target whisper-cli --parallel 6
done

lipo -create "$output/build-arm64/bin/whisper-cli" "$output/build-x86_64/bin/whisper-cli" \
    -output "$output/whisper-cli"
cp "$source_dir/LICENSE" "$output/whisper.cpp.LICENSE"
