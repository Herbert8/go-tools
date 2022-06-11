#!/bin/bash

# set -eu

PROJECT_ROOT=${1:-.}


# 目录不存在时退出
if [ ! -d "$PROJECT_ROOT" ]; then
    echo "Fail: Directory \"$PROJECT_ROOT\" not exists."
    exit 1
fi

# 获取完整路径
PROJECT_ROOT=$(cd "$PROJECT_ROOT" && pwd)
readonly PROJECT_ROOT


# 默认将主模块位置设置为 $PROJECT_ROOT/cmd/app
MAIN_MODULE_PATH=$PROJECT_ROOT/cmd/app
# 如果 $PROJECT_ROOT/cmd/app 不存在，则认为当前目录为主模块
if [ ! -d "$MAIN_MODULE_PATH" ]; then
    MAIN_MODULE_PATH=$PROJECT_ROOT
fi
readonly MAIN_MODULE_PATH

# 构建内容输出目录
readonly BUILD_PATH=$PROJECT_ROOT/build


# App name
app_name=$(basename "$PROJECT_ROOT")
app_name=${app_name// /_}


show_msg () {
    echo "$@"
}


need_show_waiting () {
    local allTaskCount
    local runningTaskCount

    allTaskCount=$(( ${#platforms[@]} + 1 ))
    runningTaskCount=$(jobs -r | wc -l)

    # echo "$allTaskCount $runningTaskCount"

    [[ "$runningTaskCount" -ge "$allTaskCount" ]]
}


show_waiting () {
    while need_show_waiting; do
        echo -n '.'
        sleep 0.5
    done   
}


# go tool dist list 获取完整平台支持列表

go_build () {
    local platform
    platform=${1:-''}
    local exe_file
    local build_info
    if [[ "${platform}" != "" ]]; then
        local os
        os=$(echo "${platform}" | awk -F '/' '{print $1}')
        local arch
        arch=$(echo "${platform}" | awk -F '/' '{print $2}')

        # exe file
        exe_file="$BUILD_PATH/${app_name}_${os}_${arch}"
        build_info="\n[OS: $os  CPU: $arch]"
        (cd "$PROJECT_ROOT" && CGO_ENABLED=0 GOOS=$os GOARCH=$arch go build -a -o "$exe_file" "$MAIN_MODULE_PATH")
    else
        # exe file
        exe_file="$BUILD_PATH/${app_name}"
        build_info="\n[$(uname -a)]"
        (cd "$PROJECT_ROOT" && go build -a -o "$exe_file" "$MAIN_MODULE_PATH")
    fi
    build_info="\n${build_info}\nFile Name = [$(basename "$exe_file")]"
    build_info="\n${build_info}\nFull Path = [$exe_file]"
    build_info="$build_info\nSHA256 = $(openssl sha256 < "$exe_file")"
    show_msg -e "$build_info"
}

readonly platforms=(
# aix/ppc64
# android/386
# android/amd64
# android/arm
# android/arm64
darwin/amd64
darwin/arm64
# dragonfly/amd64
# freebsd/386
# freebsd/amd64
# freebsd/arm
# freebsd/arm64
# illumos/amd64
# ios/amd64
# ios/arm64
# js/wasm
# linux/386
linux/amd64
# linux/arm
# linux/arm64
# linux/mips
# linux/mips64
# linux/mips64le
# linux/mipsle
# linux/ppc64
# linux/ppc64le
# linux/riscv64
# linux/s390x
# netbsd/386
# netbsd/amd64
# netbsd/arm
# netbsd/arm64
# openbsd/386
# openbsd/amd64
# openbsd/arm
# openbsd/arm64
# openbsd/mips64
# plan9/386
# plan9/amd64
# plan9/arm
# solaris/amd64
windows/386
windows/amd64
# windows/arm
# windows/arm64
)

echo
echo "Source code path = [$PROJECT_ROOT]"

# 构建当前平台应用
echo
go_build &

# 构建指定平台应用
for platform in "${platforms[@]}"; do
    go_build "$platform" &
done

echo -n "Building [$app_name] "
show_waiting

wait


echo
echo Build output directory: ["$BUILD_PATH"]
ls -lh "$BUILD_PATH"
echo