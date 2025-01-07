#!/usr/bin/env bash

set -eu
set -o pipefail

show_msg() {
    echo "$@"
}

print_colored_text() {
    local attrs=''
    [[ "$#" -gt "1" ]] && for ((i = 2; i <= $#; i++)); do
        attrs=${attrs}${!i}';'
    done
    attrs=${attrs%;}
    local msg=${1-}
    echo -ne "\033[0;${attrs}m${msg}"
}

show_help() {
    cat <<EOF
NAME:
   Go Build - A handy Go language build script.

USAGE:
   gobuild [-a] [-c] [-m]

OPTIONS:
   -a               Force rebuilding of packages that are already up-to-date.
   -c               Clean up the contents of the "build" folder.
   -m               Multi-platform build.
   -h               Show help message.
EOF
}

# 输出标题
print_title() {
    print_colored_text "$1" "${TEXT_BOLD_BRIGHT}" "${COLOR_F_LIGHT_GREEN}"
    print_colored_text '' "$TEXT_RESET_ALL_ATTRIBUTES"
}

# 输出错误
print_error() {
    print_colored_text "$1" "$COLOR_F_LIGHT_RED"
    print_colored_text '' "$TEXT_RESET_ALL_ATTRIBUTES"
}

# 函数：print_scroll_in_range
# 功能：在终端窗口中以滚动形式显示输入文本，限制在指定的行数范围内
# 参考：https://zyxin.xyz/blog/2020-05/TerminalControlCharacters/
print_scroll_in_range() {
    # 参数1：scroll_lines，最多显示的滚动行数，默认为8行
    local scroll_lines=${1:-8}
    # 参数2：chars_per_line，每行的最大字符数，超过部分会被截断，默认为120字符
    local chars_per_line=${2:-120}

    # txt：保存当前显示的所有文本内容
    local txt=''
    # last_line_count：记录上次输出时的行数
    local last_line_count=0
    # 用于标记是否开始记录 log
    local need_start_log=0
    # 最终要输出的文本
    local final_output_message=''
    # 从标准输入读取每一行内容
    while read -r line; do

        # 如果是 # 开头，并且之前没有标记过（避免每次都处理字符串导致性能问题），则开始记录
        if [[ $need_start_log -eq 0 && "$line" == '# '* ]]; then
            need_start_log=1
        fi

        # 如果需要开始记录，则开始记录行信息
        if [[ $need_start_log -eq 1 ]]; then
            final_output_message="$final_output_message"$'\n'"$line"
        fi

        # 截取每一行的前 chars_per_line 个字符，避免超出宽度换行
        line=${line:0:$chars_per_line}

        # 如果 last_line_count 大于 0，则将光标上移 last_line_count 行以覆盖旧内容
        [[ "${last_line_count}" -gt "0" ]] && echo -ne "\033[${last_line_count}A"

        # 将新读取的行格式化并拼接到 txt
        if [[ -z "$txt" ]]; then
            # 如果 txt 为空，初始化 txt，使用 ANSI 转义代码 \033[2m 设置为淡色，\033[K 清除行尾
            txt=$(echo -e "\033[2m$line\033[K" | tail -n"$scroll_lines")
        else
            # 非第一行时，将新行追加到 txt，限制总行数为 scroll_lines
            txt=$(echo -e "$txt\n$line\033[K" | tail -n"$scroll_lines")
        fi

        # 计算当前文本内容的行数
        last_line_count=$(($(wc -l <<<"$txt")))

        # 输出更新后的文本内容
        echo "$txt"
    done

    # 重置颜色
    echo -ne "\033[0m"

    # 如果有输出的行数，调用 clear_scroll_lines 清除最后的显示
    if [[ "$last_line_count" -gt "0" ]]; then
        clear_scroll_lines "$last_line_count"
    fi

    if [[ -n "$final_output_message" ]]; then
        print_error "$final_output_message"
    fi

}

# 函数：clear_scroll_lines
# 功能：在终端中清除指定数量的行，使输出区域变得干净
clear_scroll_lines() {
    # 参数1：lines_count，要清除的行数。如果未传入参数，默认值为空
    local lines_count=${1:-}

    # 如果 lines_count 为空，则直接返回，不做任何操作
    [[ -z "$lines_count" ]] && return

    # 将光标向上移动 lines_count 行
    echo -ne "\033[${lines_count}A"

    # 逐行清除 lines_count 行内容
    for ((i = 0; i < lines_count; i++)); do
        # \033[K 清除当前光标位置到行尾的内容
        echo -e "\033[K"
    done

    # 将光标再次移动回起始位置
    echo -ne "\033[${lines_count}A"
}

# go tool dist list 获取完整平台支持列表
go_build() {
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
        # 之前是通过 uname 检测当前平台
        # 现在已经改为在调用时通过执行 go version 来获取当前平台信息
        # 此分支暂时保留，但应该不再起作用
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
    do_build() {
        if [[ "${FORCE_REBUILD}" == "1" ]]; then
            go build --ldflags="-s -w -X 'main.buildTime=$(date +'%Y-%m-%d %H:%M:%S %z')'" "$@" -a -o "$exe_file" "$main_module_path"
        else
            go build --ldflags="-s -w -X 'main.buildTime=$(date +'%Y-%m-%d %H:%M:%S %z')'" "$@" -o "$exe_file" "$main_module_path"
        fi
    }

    start=$(date +%s)
    # 构建
    (
        cd "$GO_MOD_ROOT" && do_build -v 2>&1 | print_scroll_in_range 5
    ) || {
        # print_error "\nSome errors occurred during the build process. Exit with error code $?."
        exit 2
    }

    # 显示 SHA256
    build_info="SHA256 = $(openssl sha256 <"$exe_file")"
    show_msg -e "$build_info"

    end=$(date +%s)

    elapsed=$((end - start))
    echo "Building this module takes ${elapsed} seconds."

}

go_clean_build() {
    local build_dir=$GO_MOD_ROOT/build
    echo "$build_dir"
    if [[ -d "$build_dir" ]]; then
        rm -rf "${build_dir:?}"/*
    fi
}

main() {

    FORCE_REBUILD=''
    MULTI_PLATFORM_BUILD=''
    CLEAN_BUILD_DATA=''

    # 处理脚本参数
    # -a 彻底构建，并且强制构建未变更的内容
    # -m 包括构建所有支持的平台
    # -c 清理已经构建的内容
    while getopts "acmh" opt_name; do # 通过循环，使用 getopts，按照指定参数列表进行解析，参数名存入 opt_name
        case "$opt_name" in           # 根据参数名判断处理分支
        'a')                          # -a 参数
            FORCE_REBUILD=1
            ;;
        'c')
            CLEAN_BUILD_DATA=1
            ;;
        'm')
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

    # clear

    # 删除已解析的参数
    shift $((OPTIND - 1))

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

    # 清理构建数据并退出
    if [[ "$CLEAN_BUILD_DATA" -eq "1" ]]; then
        go_clean_build
    fi

    proj_name=$(basename "$GO_MOD_ROOT")

    # 定义基本颜色值
    readonly TEXT_RESET_ALL_ATTRIBUTES=0
    readonly TEXT_BOLD_BRIGHT=1
    # readonly TEXT_UNDERLINED=4
    readonly COLOR_F_LIGHT_RED=91
    readonly COLOR_F_LIGHT_GREEN=92
    # readonly COLOR_F_LIGHT_YELLOW=93

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

    # 支持的平台和 CPU 架构列表
    # 通过该命令获取：go tool dist list
    SUPPORTED_PLATFORMS_LIST=(
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
        # windows/386
        windows/amd64
        # windows/arm
        windows/arm64
    )

    # 加载工程自己定义的支持平台设置
    local custom_supported_platform_config=$GO_MOD_ROOT/scripts/supported_platforms.sh
    [[ -f "$custom_supported_platform_config" ]] && source "$custom_supported_platform_config"

    # echo
    info=$(
        print_title "[Go Version Infomation]"
        echo
        go version
        echo "  GOBIN=$(which go) -> $(greadlink -f "$(which go)")"
        echo "  GOVERSION=$(go env GOVERSION)"
        echo "  GOENV=$(go env GOENV)"
        echo "  GOPATH=$(go env GOPATH)"
        echo "  GOPROXY=$(go env GOPROXY)"
        echo "  GOROOT=$(go env GOROOT)"
        echo "  GOTOOLDIR=$(go env GOTOOLDIR)"
    )

    echo "$info" | boxes -d columns

    echo
    echo "Source code path = [$PROJECT_ROOT], module ROOT = [$GO_MOD_ROOT]"

    startTime=$(date +%s)

    # 为每个 main_module 执行构建
    for main_module in "${MAIN_MODULE_PATH_LIST[@]}"; do
        # 如果指定了多平台构建，则构建指定平台应用
        if [[ "${MULTI_PLATFORM_BUILD}" == "1" ]]; then
            for platform in "${SUPPORTED_PLATFORMS_LIST[@]}"; do
                echo
                go_build "$main_module" "$platform"
            done
        else
            # 构建当前平台应用
            echo
            go_build "$main_module" "$(go version | awk '{print $4}')"
            echo
        fi
    done

    # echo -n "Building "
    # show_waiting

    # wait

    endTime=$(date +%s)

    # echo
    summary=$(
        print_title "Build output directory: [$BUILD_PATH]"
        echo
        echo
        echo "Building all app takes a total of $((endTime - startTime)) seconds."
        echo
        gls -lph --time-style=long-iso --group-directories-first --color=always "$BUILD_PATH"
    )
    echo "$summary" | boxes -d parchment
    # echo "$summary" | boxes -d ian_jones
}

main "$@"
