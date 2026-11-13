#!/bin/bash
# Build the real Quickshell (v0.3.2) in a cloud container (Ubuntu, root), to
# test a theme's shell before the user installs it. About 15 minutes, once
# per container. This is what worked last time; adapt where the container
# differs.
#
#   docs/harness/build.sh            everything, into $Q (default /tmp/qsreal)
#
# Then: docs/harness/run.sh <theme-id>   (see that file)
set -e
Q=${Q:-/tmp/qsreal}
mkdir -p "$Q" && cd "$Q"

# a compositor to run it under, screenshots, a session bus, Lua for config checks
apt-get update >apt.log 2>&1 || true      # (a fresh container knows no packages yet)
apt-get install -y sway grim dbus-x11 lua5.4 libpam0g-dev >>apt.log 2>&1 || echo "apt: see $Q/apt.log"

# Qt 6.12 and the build tools, from conda-forge (the distribution's Qt is too old)
[ -x ./micromamba ] || curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xj --strip-components=1 bin/micromamba
export MAMBA_ROOT_PREFIX=$Q/mamba
[ -d env ] || ./micromamba create -y -q -p "$Q/env" -c conda-forge --override-channels \
    qt6-main=6.12 qt6-wayland=6.12 cmake ninja pkg-config gxx_linux-64 gcc_linux-64 \
    "wayland>=1.22" wayland-protocols cli11 libdrm jemalloc pipewire libxcb libgbm \
    vulkan-headers libvulkan-headers spirv-tools libglib dbus fontconfig
eval "$(./micromamba shell hook -s bash)"
micromamba activate "$Q/env"

[ -d src ] || git clone -q --branch v0.3.2 --depth 1 https://github.com/quickshell-mirror/quickshell src
cd src
# (if PAM is not found: point -DCMAKE_CXX_FLAGS=-I<dir>/include and the linker
# at a folder holding the system's security/*.h and libpam.so)
cmake -GNinja -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_PREFIX_PATH="$CONDA_PREFIX" -DCMAKE_INSTALL_PREFIX="$Q/inst" \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,$CONDA_PREFIX/lib -Wl,-rpath-link,$CONDA_PREFIX/lib" \
    -DCRASH_HANDLER=OFF -DUSE_JEMALLOC=OFF -DSERVICE_POLKIT=OFF -DX11=OFF -DDISTRIBUTOR="local conda build"
cmake --build build -j4
cmake --install build
printf 'output HEADLESS-1 mode 1920x1200 position 0 0\ndefault_border none\n' >"$Q/sway.conf"
echo "built: $Q/inst/bin/quickshell"
