# 坐标转换回归测试

测试直接读取本仓库中的坐标实现，不维护源码副本。两个测试均在独立 Elixir
进程中运行，隔离 HTTP 请求，不需要真实高德密钥或数据库，也不会访问生产服务。

在仓库根目录运行 13 项源码测试：

```sh
elixir customizations/coordinate/verify_patch.exs
```

此测试通过替身隔离 HTTP、数据库和依赖，加载实际 Geocoder 源码及实际
`create_address/1` 函数。覆盖官方无密钥回退、高德坐标转换、浮点请求六位精度、
中文地址解析、地址刷新避免二次转换、旧地址身份保留及地址去重。

已有编译好的生产依赖时，运行另外 5 项真实依赖测试：

```sh
elixir customizations/coordinate/verify_real_dependencies.exs
```

此测试使用实际 Tesla 中间件、Decimal 和 Ecto Address，仅替换 HTTP 适配器。
默认寻找本仓库 `elixir/_build/prod`，兼容 `_build/prod`；不会启动 TeslaMate
应用或连接数据库。

可通过环境变量调整目录：

| 变量 | 含义 |
| --- | --- |
| `COORDINATE_SOURCE_ROOT` | 源码仓库根目录，或包含 `lib/` 的 Elixir 应用目录；默认从脚本位置解析仓库根目录。 |
| `COORDINATE_DEPENDENCY_ROOT` | 包含 `_build/prod` 的编译项目目录；默认根据源码目录检测。 |

例如在官方构建镜像中，仓库挂载为 `/repository`、编译项目位于 `/opt/app/elixir`：

```sh
COORDINATE_SOURCE_ROOT=/repository \
COORDINATE_DEPENDENCY_ROOT=/opt/app/elixir \
elixir /repository/customizations/coordinate/verify_real_dependencies.exs
```

目录调整只影响读取的位置；测试始终使用目标仓库的最终坐标源码。
