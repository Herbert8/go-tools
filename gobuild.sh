#!/usr/bin/env bash


set -eu

print_colored_text () {
    local attrs=''
    [[ "$#" -gt "1" ]] && for (( i=2;i<=$#;i++ )); do
        attrs=${attrs}${!i}';'
    done
    attrs=${attrs%;}
    local msg=${1-}
    echo -ne "\033[0;${attrs}m${msg}"
}


FORCE_REBUILD=''
MULTI_PLATFORM_BUILD=''

show_help () {
    cat << EOF
NAME:
   Go Build - A handy Go language build script.

USAGE:
   gobuild [-a] [-m]

OPTIONS:
   -a               Force rebuilding of packages that are already up-to-date.
   -m               Multi-platform build.
   -h               Show help message.
EOF
}

# 处理脚本参数
# -a 彻底构建，包括构建所有支持的平台，并且强制构建未变更的内容
while getopts "amh" opt_name # 通过循环，使用 getopts，按照指定参数列表进行解析，参数名存入 opt_name
do
    case "$opt_name" in # 根据参数名判断处理分支
        'a') # -a 参数
            FORCE_REBUILD=1
            ;;
        'm') # -m 参数
            MULTI_PLATFORM_BUILD=1
            ;;
        'h') # 显示帮助
            show_help
            exit 1
            ;;

        ?) # 其它未指定名称参数
            echo "Unknown argument(s)."
            exit 2
            ;;
    esac
done

clear

# 删除已解析的参数
shift $((OPTIND-1))


PROJECT_ROOT=${1:-.}


# 目录不存在时退出
if [[ ! -d "$PROJECT_ROOT" ]]; then
    echo "Fail: Directory \"$PROJECT_ROOT\" not exists."
    exit 1
fi

# 根据用户输入，获取工程完整路径
# 这里只作为工作起始位置，后续会计算模块位置，作为起始位置
# 主要是应对 指定目录 是工程中的一个子目录的场景
PROJECT_ROOT=$(cd "$PROJECT_ROOT" && pwd)
readonly PROJECT_ROOT

# 获取 go.mod 文件位置
# 如果指定目录 不在 Go 工程目录中（不是工程目录，也不是子目录）
# 则会返回 /dev/null
GO_MOD_FILE=$(cd "$PROJECT_ROOT" && go env GOMOD)
readonly GO_MOD_FILE

# 获取 go.mod 所在目录，作为 模块根目录
# 如果获取的模块文件为 /dev/null，则使用指定的工程目录作为模块根目录
if [[ "${GO_MOD_FILE}" == "/dev/null" ]]; then
    GO_MOD_ROOT=${PROJECT_ROOT}
else # 否则获取 go.mod 所在目录作为模块根目录
    GO_MOD_ROOT=$(dirname "$GO_MOD_FILE")
fi
readonly GO_MOD_ROOT


# 默认将 $GO_MOD_ROOT/cmd/* 作为主模块
MAIN_MODULE_PATH_LIST=()
for mod_path in "$GO_MOD_ROOT/cmd"/*; do
    if [[ -d "$mod_path" ]]; then
        MAIN_MODULE_PATH_LIST[${#MAIN_MODULE_PATH_LIST[@]}]=$mod_path
    fi
done


# 如果 $GO_MOD_ROOT/cmd/* 不存在，则认为当前目录为主模块
if [[ "${#MAIN_MODULE_PATH_LIST[@]}" -eq "0" ]]; then
    MAIN_MODULE_PATH_LIST[${#MAIN_MODULE_PATH_LIST[@]}]=$GO_MOD_ROOT
fi
readonly MAIN_MODULE_PATH_LIST

# 构建内容输出目录
BUILD_PATH=$GO_MOD_ROOT/build
readonly BUILD_PATH


show_msg () {
    echo "$@"
}


# need_show_waiting () {
#    local allTaskCount
#    local runningTaskCount

#    # platforms 存放指定平台，加上一个当前平台，乘以模块数量
#    allTaskCount=$(( ( ${#platforms[@]} + 1 ) * ${#MAIN_MODULE_PATH_LIST[@]} ))
#    runningTaskCount=$(jobs -r | wc -l)

#    # echo "$allTaskCount $runningTaskCount"

#    [[ "$runningTaskCount" -ge "$allTaskCount" ]]
# }


# show_waiting () {
#    while need_show_waiting; do
#        echo -n '.'
#        sleep 0.5
#    done
# }

proj_name=$(basename "$GO_MOD_ROOT")


# 定义基本颜色值
readonly TEXT_RESET_ALL_ATTRIBUTES=0
readonly TEXT_BOLD_BRIGHT=1
# readonly TEXT_UNDERLINED=4
readonly COLOR_F_LIGHT_RED=91
readonly COLOR_F_LIGHT_GREEN=92
# readonly COLOR_F_LIGHT_YELLOW=93

# 输出标题
print_title () {
    print_colored_text "$1" "${TEXT_BOLD_BRIGHT}" "${COLOR_F_LIGHT_GREEN}"
    print_colored_text '' "$TEXT_RESET_ALL_ATTRIBUTES"
}

# 输出错误
print_error () {
    print_colored_text "$1" "$COLOR_F_LIGHT_RED"
    print_colored_text '' "$TEXT_RESET_ALL_ATTRIBUTES"
}

# 在指定范围内滚动
# 参考：https://zyxin.xyz/blog/2020-05/TerminalControlCharacters/
print_scroll_in_range () {
    # 默认最多显示滚动行数，默认为 8
    local scroll_lines=${1:-8}
    # 每行字符数，避免折行，默认 120
    local chars_per_line=${2:-120}
    local txt=''
    local last_line_count=0
    while read -r line; do
        line=${line:0:$chars_per_line}
        [[ "${last_line_count}" -gt "0" ]] && echo -ne "\033[${last_line_count}A"
        if [[ -z "$txt" ]]; then
            txt=$(echo -e "\033[2m$line\033[K" | tail -n"$scroll_lines")
        else
            txt=$(echo -e "$txt\n$line\033[K" | tail -n"$scroll_lines")
        fi
        last_line_count=$(( $(wc -l <<< "$txt") ))
        echo "$txt"
    done
    echo -ne "\033[0m"
}

# 清理前面输出的指定行数
clear_lines () {
    local lines_count=${1:-}
    [[ -z "$lines_count" ]] && return
    echo -ne "\033[${lines_count}A"
    for ((i=0; i<lines_count; i++)); do
        echo -e "\033[K"
    done
    echo -ne "\033[${lines_count}A"
}

# go tool dist list 获取完整平台支持列表
go_build () {
    local main_module_path
    main_module_path=${1:-'./'}
    local platform
    platform=${2:-''}
    # App name
    local app_name
    app_name=$(basename "$main_module_path")
    local exe_file
    local build_info
    local os
    local arch
    if [[ "${platform}" != "" ]]; then
        os=$(echo "${platform}" | awk -F '/' '{print $1}')
        arch=$(echo "${platform}" | awk -F '/' '{print $2}')

        export CGO_ENABLED=0
        export GOOS=$os
        export GOARCH=$arch
    else
        # 当前平台
        os=$(uname)
        arch=$(uname -m)

        unset CGO_ENABLED
        unset GOOS
        unset GOARCH
    fi

    # exe file
    exe_file="$BUILD_PATH/${proj_name}_${app_name}_${os}_${arch}"
    exe_file=${exe_file// /_}

    # 构建信息
    # 平台信息
    build_info="[OS: $os  CPU: $arch]"
    print_title "$build_info"
    echo
    # 文件名
    build_info="File Name = [$(basename "$exe_file")]"
    # 完整路径
    build_info="${build_info}\nFull Path = [$exe_file]"
    show_msg -e "$build_info"

    local start
    local end

    # 构建函数，根据执行脚本时指定的参数，决定在 go build 中是否也指定 -a 参数，进行完整构建
    do_build () {
        if [[ "${FORCE_REBUILD}" == "1" ]]; then
            go build "$@" -a -o "$exe_file" "$main_module_path"
        else
            go build "$@" -o "$exe_file" "$main_module_path"
        fi
    }

    start=$(date +%s)
    # 构建
    (
        cd "$GO_MOD_ROOT" &&  do_build -v 2>&1 | print_scroll_in_range 5 && clear_lines 5
    ) || {
        print_error "\n\Some errors occurred during the build process. Exit wiht error code $?."
        exit 2
    }


    # 显示 SHA256
    build_info="SHA256 = $(openssl sha256 < "$exe_file")"
    show_msg -e "$build_info"

    end=$(date +%s)

    elapsed=$(( end - start ))
    echo "Building this module takes ${elapsed} seconds."

}

# 支持的平台和 CPU 架构列表
# 通过该命令获取：go tool dist list
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
linux/arm64
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

# echo
info=$(print_title "[Go Version Infomation]"
echo
go version
echo "  GOBIN=$(greadlink -f go)"
echo "  GOVERSION=$(go env GOVERSION)"
echo "  GOENV=$(go env GOENV)"
echo "  GOPATH=$(go env GOPATH)"
echo "  GOPROXY=$(go env GOPROXY)"
echo "  GOROOT=$(go env GOROOT)"
echo "  GOTOOLDIR=$(go env GOTOOLDIR)")

echo "$info" | boxes -d columns

echo
echo "Source code path = [$PROJECT_ROOT], module ROOT = [$GO_MOD_ROOT]"

startTime=$(date +%s)

# 为每个 main_module 执行构建
for main_module in "${MAIN_MODULE_PATH_LIST[@]}"; do
    # 如果指定了多平台构建，则构建指定平台应用
    if [[ "${MULTI_PLATFORM_BUILD}" == "1" ]]; then
        for platform in "${platforms[@]}"; do
            echo
            go_build "$main_module" "$platform"
        done
    else
        # 构建当前平台应用
        echo
        go_build "$main_module"
        echo
    fi
done

# echo -n "Building "
# show_waiting

# wait

endTime=$(date +%s)


# echo
summary=$(print_title "Build output directory: [$BUILD_PATH]"
echo
echo
echo "Building all app takes a total of $(( endTime - startTime )) seconds."
echo
gls -lph --time-style=long-iso --group-directories-first --color=always "$BUILD_PATH")
echo "$summary" | boxes -d parchment
# echo "$summary" | boxes -d ian_jones