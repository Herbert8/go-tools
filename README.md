# Go Tools



- gonew

根据 Go 推荐的工程结构，创建工程目录结构，包含主应用和测试文件。

参考：

- [golang-standards](https://github.com/golang-standards) / [project-layout](https://github.com/golang-standards/project-layout)
- [该如何组织 Go 项目结构？](https://zhuanlan.zhihu.com/p/346573562)

```
.
├── api
├── assets
├── build
├── cmd
│   └── app
│       └── app.go
├── configs
├── deployments
├── docs
├── examples
├── go.mod
├── init
├── internal
├── pkg
├── scripts
│   └── supported_platforms.sh
├── test
│   └── app_test.go
├── third_party
├── tools
├── web
└── website
```



- gobuild

根据 Go 推荐的工程结构，执行多平台构建，显示更明晰的构建过程，提供更丰富的信息。

```
NAME:
   Go Build - A handy Go language build script.

USAGE:
   gobuild [-a] [-c] [-m]

OPTIONS:
   -a               Force rebuilding of packages that are already up-to-date.
   -c               Clean up the contents of the "build" folder.
   -m               Multi-platform build.
   -h               Show help message.
```

