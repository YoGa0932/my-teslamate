# my-teslamate-v3

本分支以官方 TeslaMate v4.4.0 为基础，继承 `my-teslamate-v2` 的 Git 历史，只保留高德坐标能力和官方 Grafana 仪表盘的中文显示。

## 坐标能力

应用代码仅修改 `elixir/lib/teslamate/locations.ex` 与 `elixir/lib/teslamate/locations/geocoder.ex`：

- 中国范围内的地址查询调用高德，将 WGS84 转为 GCJ-02，并取得中文地址。
- 通过运行环境的 `AMAP_KEY` 读取单个或逗号分隔的多个密钥，保留按日轮换。
- 高德 HTTP 请求使用固定六位小数；保存地址时保留返回坐标的原精度与身份。
- 已有高德地址刷新时不重复转换 GCJ-02，并保留地址 ID。
- 未配置高德密钥时，新查询使用官方 Nominatim；已有高德地址保持原样。

车辆 `positions` 保留官方 WGS84 数据；数据库结构、位置采集、前端地图、MQTT 与围栏逻辑均沿用官方实现。

测试见 `customizations/coordinate/README.md`。隔离测试直接读取当前分支源码，另提供使用真实 Tesla、Decimal、Ecto 依赖的测试。

## 官方中文仪表盘

官方英文仪表盘保留在 `grafana/dashboards/`。对应中文版本为 `grafana/dashboards-zh/`，包含当前官方全部 24 个仪表盘。仅改变名称、说明、标签、表头和图例等显示内容；SQL、数据源与仪表盘 UID、变量内部值、单位、原有转换、布局和链接保持官方语义。

从本分支根目录重建并核验：

```sh
python3 customizations/grafana-zh/translate.py
python3 customizations/grafana-zh/verify.py
elixir customizations/coordinate/verify_patch.exs
```

Grafana 使用官方 `teslamate/grafana:4.4.0` 镜像，默认界面语言可设置为 `GF_USERS_DEFAULT_LANGUAGE=zh-Hans`。中文 JSON 按官方三个提供器分别挂载；部署复制步骤见 `customizations/grafana-zh/README.md`。

TeslaMate 使用本分支原有的官方 Dockerfile 构建：

```sh
docker build -t teslamate-custom:4.4.0-gcj02 .
```

其余部署服务继续按照该官方版本的 Docker Compose 说明配置 PostgreSQL、Grafana 与 Mosquitto，并沿用已有部署的持久数据卷及原加密密钥。

## 跟随官方版本

1. 获取并核验官方正式版本 tag，在新工作分支合入上游。
2. 检查两处坐标改动在新的官方源码中仍适用，运行坐标测试与实际高德转换验证。
3. 从新的官方英文仪表盘重新生成中文文件；新增文字需要补全词典，不能沿用旧版本仪表盘文件。
4. 核验全部中文文件与新官方源文件对应，验证实际 Grafana 查询、常用单位和链接。
5. 使用新版本官方 Dockerfile 构建应用，更新应用和官方 Grafana 镜像；数据库主版本变化需单独迁移和恢复验证。
6. 切换前备份数据及机密配置，切换后确认 Tesla 登录、车辆采集、坐标转换、仪表盘和备份正常。

运行配置、密钥、数据库和运行报告不保存在 Git 中。服务器专属部署与验收记录独立保存。
