#!/bin/sh
green='\033[0;32m'
red='\033[0;31m'
nocolor='\033[0m'
deps="meson ninja patchelf unzip curl pip flex bison zip"
workdir="$(pwd)/turnip_workdir"
driverdir="$workdir/turnip_module"
ndkver="android-ndk-r25c"
clear

echo "Checking system for required Dependencies ..."
for deps_chk in $deps; do
  sleep 0.25
  if command -v $deps_chk >/dev/null 2>&1; then
    echo -e "$green - $deps_chk found $nocolor"
  else
    echo -e "$red - $deps_chk not found, can't continue. $nocolor"
    deps_missing=1
  fi
done

if [ "$deps_missing" == "1" ]; then
  echo "Please install missing dependencies" && exit 1
fi

echo "Installing python Mako dependency (if missing) ..." $'\n'
pip install mako &> /dev/null

echo "Creating and entering the work directory ..." $'\n'
mkdir -p $workdir && cd $workdir

echo "Downloading android-ndk from google server (~506 MB) ..." $'\n'
curl https://dl.google.com/android/repository/"$ndkver"-linux.zip --output "$ndkver"-linux.zip &> /dev/null
###
echo "Extracting android-ndk to a folder ..." $'\n'
unzip "$ndkver"-linux.zip &> /dev/null

echo "Downloading mesa source (~30 MB) ..." $'\n'
curl https://gitlab.freedesktop.org/mesa/mesa/-/archive/main/mesa-main.zip --output mesa-main.zip &> /dev/null
###
echo "Extracting mesa source to a folder ..." $'\n'
unzip mesa-main.zip &> /dev/null
cd mesa-main

echo "Creating meson cross file ..." $'\n'
ndk="$workdir/$ndkver/toolchains/llvm/prebuilt/linux-x86_64/bin"
cat <<EOF >"android-arm"
[binaries]
ar = '$ndk/llvm-ar'
c = ['ccache', '$ndk/arm-linux-androideabi31-clang']
cpp = ['ccache', '$ndk/arm-linux-androideabi31-clang++', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '-static-libstdc++']
c_ld = 'lld'
cpp_ld = 'lld'
strip = '$ndk/arm-linux-androideabi-strip'
pkgconfig = ['env', 'PKG_CONFIG_LIBDIR=NDKDIR/pkgconfig', '/usr/bin/pkg-config']
[host_machine]
system = 'android'
cpu_family = 'arm'
cpu = 'armv7'
endian = 'little'
EOF

echo "Generating build files ..." $'\n'
meson build-android-arm --cross-file $workdir/mesa-main/android-arm -Dbuildtype=release -Dplatforms=android -Dplatform-sdk-version=31 -Dandroid-stub=true -Dgallium-drivers= -Dvulkan-drivers=freedreno -Dfreedreno-kmds=kgsl -Db_lto=true &> $workdir/meson_log

echo "Compiling build files ..." $'\n'
ninja -C build-android-arm &> $workdir/ninja_log

echo "Using patchelf to match soname ..." $'\n'
cp $workdir/mesa
