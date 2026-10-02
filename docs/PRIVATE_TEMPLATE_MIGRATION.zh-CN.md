# 私有代码与作图案例迁移

本流程把已有案例整理为可复用的私有模板，再通过 SFL 已有入口发布到本机 **Local Published**。图库客户端负责资产保存、检索、精确预览和材料化；绘图、轻量数据转换、运行环境以及图片检查由宿主完成。工具不会绑定图库、安装依赖、运行原始代码或公开材料。

## 来源盘点

在仓库根目录运行，路径使用自己的私有目录：

```powershell
node scripts/private-template-tools.mjs inventory --source "X:\Sources\CollectionA" --source "X:\Sources\CollectionB" --out "X:\PrivateTemplates\inventory"
```

`--source` 可以重复。来源只读，输出必须位于来源目录之外。结果包含 `inventory.json`、UTF-8 CSV 和 `summary.md`：普通文件与 ZIP 成员的 SHA-256、文件类型、来源日期线索、图家族线索、R/Python 静态依赖以及内容重复组。记录数包含归档成员，不能当作独立模板数量；图家族来自名称，依赖来自静态文本，不代表科学功能、完整依赖、安装成功或代码运行成功。

ZIP 通过中央目录枚举，支持嵌套 ZIP，不解压到来源目录。UTF-8 标志及 Unicode 路径扩展优先；旧式未标 UTF-8 的非 ASCII 名称先按 GB18030 解码，GB18030 无效时退回合法 UTF-8，存在另一种合法 UTF-8 解读时记录 `alternateUtf8Name`。这属于中文来源的明确约定，不能宣称自动识别所有历史 ZIP 字符集。加密条目、符号链接、损坏条目、ZIP64、其他归档格式以及超过限额的内容会写入 `issues`，不会假装盘点成功。

默认限制：单 ZIP 256 MiB、单展开成员 64 MiB、累计展开内容 4 GiB、代码文本 4 MiB、嵌套深度 4 层、最多 100,000 条记录。JSON 保存本次限额、跳过原因与 `summary.complete`。这些限额可以通过导出的 JavaScript 函数 `inventorySources` 的 `limits` 参数调整。盘点文件含私有来源标识，只保存在私有目录，不提交到公开仓库。

## 私有模板包

每个模板使用稳定的 ASCII 目录名。目录与运行输入保持独立于 SFL 全局 Library：

```text
sc-example/
  details.json
  README.md
  data_schema.yml
  provenance.md
  params.yml
  code/plot.R
  code/common.R
  data/input.csv
  preview.png
  plot.pdf
  evidence/render.json
  evidence/sessionInfo.txt
```

入口也可以是 `code/plot.py`。公共 helper 只做验证、整形与绘图辅助；R 入口用固定字面路径读取 CSV，再把表传给 helper。SFL 当前 runtime 扫描会拒绝 `read.csv(file)` 等无法解析的动态读文件表达式，不应通过修改核心或藏起依赖绕过。参数文件和每个运行输入都要明确声明。

`details.json` 使用以下私有整理字段；它不是新增的 SFL 服务协议：

```json
{
  "title": "中文名称",
  "titleEn": "English title",
  "plotFamily": "heatmap",
  "scientificQuestion": "这张图帮助比较什么？",
  "description": "图的编码方式与可复用特点。",
  "application": "适用场景、输入前提与解释边界。",
  "dataProfile": "输入表的内容与结构。",
  "visualProfile": "布局、颜色及标记说明。",
  "packages": ["ggplot2", "yaml"],
  "inputs": [{"path": "data/input.csv", "description": "输入表说明。"}],
  "dataScope": "derived_example",
  "sourceRefs": [{"path": "私有来源路径", "archiveEntry": "code/example.R", "notes": "来源注释。"}],
  "semanticDecisions": ["说明整理时保留或改变的统计含义。"]
}
```

`dataScope` 为 `original`、`derived_example` 或 `synthetic`，分别映射为绘图验证中的 `real_data`、`example_data`、`synthetic_data`。仅保留作图所需的表、坐标或摘要；上游分析结果保留自己的统计语义。颜色或布局修改不能升级为分析重跑、因果结论或科学有效性验证。

文件名使用可移植相对路径，不能包含路径穿越、Windows 保留名、大小写冲突或符号链接。`params.yml` 自动纳入运行输入。README、数据 schema、来源说明和 details JSON 作为私有 supporting assets 保存；包内若有 `description.md`、`template.yml` 和 `plot.pdf` 也一并保留，供材料化后恢复中文说明、私有清单和矢量输出。原始来源包不随模板整体复制。

独立输入转换脚本可放在 `adapters/`。候选转换会将该目录作为 supporting reference 保存，材料化后的工作副本恢复原相对路径。适配器不进入绘图入口的依赖或绘图执行证据：宿主按需单独运行，声明对象来源、转换参数和实际转换记录，再将标准结果表交给绘图入口。SFL 不运行适配器，也不从绘图成功推断转换或上游分析通过。

## 运行证据与候选转换

宿主运行整理后的模板并看图，保存真实运行环境记录。`evidence/render.json` 至少包含：

```json
{
  "status": "passed",
  "scope": "example_data",
  "files": [
    {"path": "code/plot.R", "sha256": "实际文件SHA256"},
    {"path": "code/common.R", "sha256": "实际文件SHA256"},
    {"path": "params.yml", "sha256": "实际文件SHA256"},
    {"path": "data/input.csv", "sha256": "实际文件SHA256"},
    {"path": "preview.png", "sha256": "实际文件SHA256"}
  ]
}
```

必须覆盖全部已选代码、运行输入和 PNG，且 hash 与当前字节一致。缺失、范围不符或文件已变更时，转换器将绘图执行状态保留为 `not_run` 并给出说明。hash 核对仅证明记录与当前文件相符，仍需宿主真实运行与图片检查，不能用手填状态代替执行。

```powershell
node scripts/private-template-tools.mjs candidate --template "X:\PrivateTemplates\sc-example" --out "X:\PrivateTemplates\sc-example\candidate.json"
```

输出是官方 `figure_library_plan_publish` 的请求对象，`target` 固定为 `local`，可用 `--mode update` 明确提出更新。代码、预览、运行输入、文档与证据使用现有 asset vocabularies 和 runtime closure；所有资产记录 `license: unknown`、`distribution: local_only`。转换器不造 `confirmedBy`、不声明科学验证、不公开、不写 SFL store。

原始绝对来源路径及注释保留在私有 `details.json`/`provenance.md` 文件里；投影到 SFL provenance metadata 的是来源标识、basename、可取得的 SHA-256 和归档相对入口。未知许可不代表获得再分发授权。

在显式选定可写的全局 Library 后，把请求交给 SFL，展示真实计划和精确预览，由用户审阅。通过现有确认契约再调用 `figure_library_apply_publish`；更新旧模板必须明确选择 `mode: update`。不要手写 store 下的 Release 文件。详见 [协议](PROTOCOL.md#unified-publication-protocol) 与 [用户手册](USER_GUIDE.zh-CN.md)。

## 材料化与独立工作副本

Local Published 材料化保留 `assets/<logicalPath>`，不会直接恢复模板原目录。Local intake 还会把 `.R` 后缀规范化为 `.r`。转换器生成正确的存储身份，并在 `origin.stagingPath` 保留原来的可移植名称。

通过 SFL 精确预览、确认及材料化后运行：

```powershell
node scripts/private-template-tools.mjs work --template "X:\Project\materialized\sc-example" --out "X:\Project\work\sc-example"
```

`--out` 必须是不存在的绝对目录，实际输出位置须在材料化目录之外；目录别名或 junction 会先解析，不能借别名写入原件内部。工具核对材料化 lock、selector、文件清单与 SHA-256，再按 runtime 输入/dependency 映射恢复 CSV、参数文件和辅助代码；主入口及 supporting assets 使用记录的 staging 相对路径。拒绝缺文件、摘要不符、路径穿越、符号链接和目标碰撞，保留材料化原件，写入 `work-origin.json`，并报告 `codeExecuted: false`。

在工作副本根目录，用项目批准的 R/Python 环境运行入口，再检查图片。这里的运行属于宿主的操作，不能把辅助工具成功复制文件描述为 SFL 已运行或科学结果已复现。

## 开发验证

```powershell
node --test tests/private-template-tools.test.ts
npm run docs:check-links -- docs/PRIVATE_TEMPLATE_MIGRATION.zh-CN.md
```

针对性测试使用隔离临时目录，覆盖嵌套 GBK ZIP、内容重复、坏归档与限额、私有来源 metadata、过期执行证据、官方 Local plan/publish/materialize、完整 runtime 路径恢复及破坏性路径输入。测试用例中的绘图证据是接口 fixture，不能替代真实模板的运行验收。整个流程复用 Node ESM、现有 `fflate` 与 SFL 接口，没有新增 Python 工具运行时或修改核心服务 API。
