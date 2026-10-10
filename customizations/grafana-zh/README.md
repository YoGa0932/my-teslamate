# 官方 Grafana 仪表盘中文翻译工具

工具放在仓库的 `customizations/grafana-zh/`。默认仓库根目录由脚本位置向上两层确定，与检出目录名称无关；本次检出目录为 `my-teslamate-v3`。

保留 `grafana/dashboards/` 中的官方英文 JSON，不改动它们。生成的中文文件跟踪在 `grafana/dashboards-zh/`，保留官方根目录、`internal/` 和 `reports/` 的目录结构。

在仓库根目录运行：

```sh
python3 customizations/grafana-zh/translate.py
python3 customizations/grafana-zh/verify.py
```

也可通过 `--source` 和 `--output` 指定官方源目录及中文输出目录。两项验证工具不固定仪表盘数量，按源目录发现的文件集合和 UID 验证。`--report` 可将验证结果另存为 JSON；默认只向终端输出结果，不改写文档或词典。

`dictionary.json` 是维护的翻译词典。新增或修改的界面文字、自定义变量显示标签，以及可读的 SQL 结果别名若没有已确认的翻译，生成过程会报错；全部翻译和结构校验完成后才写入输出。更新官方源码后，补充词典，再重新生成与验证。技术标识符、品牌、单位、车辆名称、地址和固件等动态数据保留原值；SQL 生成的周期文本也保留官方逻辑。

升级到新官方版本时，建议先生成到新的空输出目录，再验证并替换原中文目录。生成器不会自动删除旧文件；若上游删除了仪表盘，核验工具会拒绝输出中残留的旧 JSON。

中文只作用于标题、说明、显示名称、图例、值映射和自定义变量显示标签。官方 SQL、字段别名、变量内部值、数据源 UID、仪表盘 UID、单位、原有转换、链接及布局保持不变。`locations.json` 中的行政区“States”按上下文翻译为“省州”。

## 部署目录

不要将含有 `internal/`、`reports/` 的中文根目录直接挂载到容器的 `/dashboards`。官方 Grafana provisioning 会递归扫描不同 provider 的目录，这样会重复加载内部及报表仪表盘。

先将根目录 JSON 单独放入 public 部署目录，与 internal、reports 分开。以下命令从仓库根目录运行，每次使用一个新的构建目录，避免残留旧文件：

```sh
dashboard_stage=$(mktemp -d "${TMPDIR:-/tmp}/teslamate-grafana-zh.XXXXXX")
mkdir -p "$dashboard_stage/public" "$dashboard_stage/internal" "$dashboard_stage/reports"
cp grafana/dashboards-zh/*.json "$dashboard_stage/public/"
cp grafana/dashboards-zh/internal/*.json "$dashboard_stage/internal/"
cp grafana/dashboards-zh/reports/*.json "$dashboard_stage/reports/"
```

在部署配置中分别挂载这三个目录：

```yaml
volumes:
  - ${DASHBOARD_DIR}/public:/dashboards:ro
  - ${DASHBOARD_DIR}/internal:/dashboards_internal:ro
  - ${DASHBOARD_DIR}/reports:/dashboards_reports:ro
```

`DASHBOARD_DIR` 指向已复制到部署主机上的构建目录；相对路径按 Compose 文件所在位置解析。沿用官方 provider 配置与容器镜像。构建目录及运行验证报告不应提交到 Git。

## 只读运行验证

`verify_runtime.py` 在已启动并连接数据库的 Grafana 实例上验证实际部署。实例地址和结果路径由调用者明确提供，不在工具中保存服务器地址或凭据：

```sh
python3 customizations/grafana-zh/verify_runtime.py \
  --url "$GRAFANA_URL" \
  --report "$REPORT_PATH" \
  --scenarios defaults,metric,imperial
```

默认检查全部已生成仪表盘的 UID、中文标题及 SQL，然后运行概览、行程、充电、温度、行程详情和充电详情的查询。读取数据库设置及变量默认值，自动选择车辆和最近完成的行程、充电记录；普通仪表盘默认查最近 90 天，详情采用所选记录的时间范围。

`--car-id` 可指定车辆，`--days` 可调整时间范围，`--all-dashboards` 可扩展到其他仪表盘。健康 API 不允许匿名访问时，会记录提示，并通过 `SELECT 1` 验证数据库连接。仅使用 GET 元数据接口及 POST `/api/ds/query`，不修改 Grafana 配置或数据库内容。

如实例需要身份验证，可使用 `--username` 配合 `--password-env`，或 `--token-env`，从调用者指定的环境变量读取凭据。运行报告放在版本控制之外。
