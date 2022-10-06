#!/bin/bash

# 工程结构参考 
# https://github.com/golang-standards/project-layout/blob/master/README.md
# https://zhuanlan.zhihu.com/p/346573562
# https://www.cnblogs.com/codexiaoyi/p/14961852.html
# https://github.com/go-kratos/kratos/blob/main/README_zh.md


cat << EOF
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
cat << EOF > "$PROJECT_ROOT/cmd/app/app.go"
package main

import "fmt"

func main() {
	fmt.Println("Create project '$(basename "$PROJECT_ROOT")' successfully!")
}
EOF

# create test
cat << EOF > "$PROJECT_ROOT/test/app_test.go"
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

# Try to run the created project
(cd "$PROJECT_ROOT" && go run "$PROJECT_ROOT/cmd/app")

# Run tests
(cd "$PROJECT_ROOT" && go test -v "$PROJECT_ROOT/test")


