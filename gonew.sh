#!/bin/bash

# 工程结构参考
# https://github.com/golang-standards/project-layout/blob/master/README.md
# https://zhuanlan.zhihu.com/p/346573562
# https://www.cnblogs.com/codexiaoyi/p/14961852.html
# https://github.com/go-kratos/kratos/blob/main/README_zh.md

cat <<EOF
 __^__                                                                            __^__
( ___ )--------------------------------------------------------------------------( ___ )
 | / | Standard Go Project Layout Reference:                                      | \ |
 | / |   https://github.com/golang-standards/project-layout/blob/master/README.md | \ |
 | / |   https://zhuanlan.zhihu.com/p/346573562                                   | \ |
 | / |   https://www.cnblogs.com/codexiaoyi/p/14961852.html                       | \ |
 |___|                                                                            |___|
(_____)--------------------------------------------------------------------------(_____)

EOF

set -eu

PROJECT_ROOT=${1:-.}

if [[ "${PROJECT_ROOT}" != "." ]]; then
	mkdir -p "$PROJECT_ROOT"
fi

# echo "$PROJECT_ROOT"

PROJECT_ROOT=$(cd "$PROJECT_ROOT" && pwd)

# echo "$PROJECT_ROOT"
# exit

mkdir -p "$PROJECT_ROOT" # && cd "$PROJECT_ROOT" || { echo "Create '$PROJECT_ROOT' failed."; exit; }

# Go Directories

mkdir -p "$PROJECT_ROOT/cmd/app"
mkdir -p "$PROJECT_ROOT/internal"
mkdir -p "$PROJECT_ROOT/pkg"
# mkdir -p "$PROJECT_ROOT/vendor"

# Service Application Directories
mkdir -p "$PROJECT_ROOT/api"

# Web Application Directories
mkdir -p "$PROJECT_ROOT/web"

# Common Application Directories
mkdir -p "$PROJECT_ROOT/configs"
mkdir -p "$PROJECT_ROOT/init"
mkdir -p "$PROJECT_ROOT/scripts"
mkdir -p "$PROJECT_ROOT/build"
mkdir -p "$PROJECT_ROOT/deployments"
mkdir -p "$PROJECT_ROOT/test"

# Other Directories

mkdir -p "$PROJECT_ROOT/docs"
mkdir -p "$PROJECT_ROOT/tools"
mkdir -p "$PROJECT_ROOT/examples"
mkdir -p "$PROJECT_ROOT/third_party"
mkdir -p "$PROJECT_ROOT/assets"
mkdir -p "$PROJECT_ROOT/website"

# init module
module_name=$(basename "$PROJECT_ROOT")
module_name=${module_name// /_}
(cd "$PROJECT_ROOT" && go mod init "$module_name")

# create app
cat <<EOF >"$PROJECT_ROOT/cmd/app/app.go"
package main

import "fmt"

// 用于存储构建时嵌入的信息
var (
	version   string
	buildTime string
)


func main() {
	fmt.Println("Create project '$(basename "$PROJECT_ROOT")' successfully!")
	fmt.Printf("Version: %s\n", version)
	fmt.Printf("Build Time: %s\n", buildTime)
}
EOF

# create test
cat <<EOF >"$PROJECT_ROOT/test/app_test.go"
package test

import (
	"log"
	"os"
	"testing"
)

func setup() {
	log.Println("Before all tests ================>>")
}

func teardown() {
	log.Println("<<================= After all tests")
}

func TestApp(t *testing.T) {
	t.Log("Running tests.")
}

func TestMain(m *testing.M) {
	setup()
	code := m.Run()
	teardown()
	os.Exit(code)
}
EOF

# # 支持的平台列表
# cat << EOF > "$PROJECT_ROOT/scripts/supported_platforms.sh"
# SUPPORTED_PLATFORMS_LIST=(
# 	# aix/ppc64
# 	# android/386
# 	# android/amd64
# 	# android/arm
# 	# android/arm64
# 	darwin/amd64
# 	# darwin/arm64
# 	# dragonfly/amd64
# 	# freebsd/386
# 	# freebsd/amd64
# 	# freebsd/arm
# 	# freebsd/arm64
# 	# illumos/amd64
# 	# ios/amd64
# 	# ios/arm64
# 	# js/wasm
# 	# linux/386
# 	linux/amd64
# 	# linux/arm
# 	# linux/arm64
# 	# linux/mips
# 	# linux/mips64
# 	# linux/mips64le
# 	# linux/mipsle
# 	# linux/ppc64
# 	# linux/ppc64le
# 	# linux/riscv64
# 	# linux/s390x
# 	# netbsd/386
# 	# netbsd/amd64
# 	# netbsd/arm
# 	# netbsd/arm64
# 	# openbsd/386
# 	# openbsd/amd64
# 	# openbsd/arm
# 	# openbsd/arm64
# 	# openbsd/mips64
# 	# plan9/386
# 	# plan9/amd64
# 	# plan9/arm
# 	# solaris/amd64
# 	# windows/386
# 	# windows/amd64
# 	# windows/arm
# 	# windows/arm64
# )
# EOF

{
	cat <<EOF
# 获得所有支持平台： go tool dist list

# 平台列表（OS/ARCH）
PLATFORMS :=
# PLATFORMS += aix/ppc64
# PLATFORMS += android/386
# PLATFORMS += android/amd64
# PLATFORMS += android/arm
# PLATFORMS += android/arm64
PLATFORMS += darwin/amd64
PLATFORMS += darwin/arm64
# PLATFORMS += dragonfly/amd64
# PLATFORMS += freebsd/386
# PLATFORMS += freebsd/amd64
# PLATFORMS += freebsd/arm
# PLATFORMS += freebsd/arm64
# PLATFORMS += freebsd/riscv64
# PLATFORMS += illumos/amd64
# PLATFORMS += ios/amd64
# PLATFORMS += ios/arm64
# PLATFORMS += js/wasm
# PLATFORMS += linux/386
PLATFORMS += linux/amd64
# PLATFORMS += linux/arm
PLATFORMS += linux/arm64
# PLATFORMS += linux/loong64
# PLATFORMS += linux/mips
# PLATFORMS += linux/mips64
# PLATFORMS += linux/mips64le
# PLATFORMS += linux/mipsle
# PLATFORMS += linux/ppc64
# PLATFORMS += linux/ppc64le
# PLATFORMS += linux/riscv64
# PLATFORMS += linux/s390x
# PLATFORMS += netbsd/386
# PLATFORMS += netbsd/amd64
# PLATFORMS += netbsd/arm
# PLATFORMS += netbsd/arm64
# PLATFORMS += openbsd/386
# PLATFORMS += openbsd/amd64
# PLATFORMS += openbsd/arm
# PLATFORMS += openbsd/arm64
# PLATFORMS += openbsd/ppc64
# PLATFORMS += openbsd/riscv64
# PLATFORMS += plan9/386
# PLATFORMS += plan9/amd64
# PLATFORMS += plan9/arm
# PLATFORMS += solaris/amd64
# PLATFORMS += wasip1/wasm
# PLATFORMS += windows/386
PLATFORMS += windows/amd64
# PLATFORMS += windows/arm
PLATFORMS += windows/arm64


APP_NAME := $module_name
BUILD_DIR := build
SRC_DIR := ./cmd/app

EOF

	cat <<'EOF'
# 默认目标
all: $(PLATFORMS)

# 针对每个平台生成可执行文件
$(PLATFORMS):
	@os_arch=($(subst /, ,$@)) && \
	echo "Building for OS=$${os_arch[0]} ARCH=$${os_arch[1]}" && \
		GOOS=$${os_arch[0]} GOARCH=$${os_arch[1]} go build --ldflags="-s -w -X 'main.version=0.0.1' -X 'main.buildTime=$$(date +'%Y-%m-%d %H:%M:%S %z')'" -o $(BUILD_DIR)/$(APP_NAME)_$${os_arch[0]}_$${os_arch[1]} $(SRC_DIR) && \
		eza -glF --time-style="+%Y-%m-%d %H:%M:%S %z" --group-directories-first --color-scale --color=auto "$(BUILD_DIR)/$(APP_NAME)_$${os_arch[0]}_$${os_arch[1]}" && \
		echo '------------------------------------------------------------------------------------------'

EOF

} >"$PROJECT_ROOT/Makefile"

# Try to run the created project
(cd "$PROJECT_ROOT" && go run --ldflags="-s -w -X 'main.version=0.0.1' -X 'main.buildTime=$(date +'%Y-%m-%d %H:%M:%S %z')'" "$PROJECT_ROOT/cmd/app")

# Run tests
(cd "$PROJECT_ROOT" && go test -v "$PROJECT_ROOT/test")
