# Scientific Figure Library · luvega 版使用说明

这是 [luvega 的 SFL fork](https://github.com/luvega/ScientificFigureLibrary)，以原项目 **0.9.0** 为当前基线，补充了 **38 个可独立运行的单细胞绘图模板**、案例迁移工具和运行目录准备工具。定制版放在 `luvega` 分支；`main` 保留上游基线。

[38 个模板与预览](examples/single-cell/README.md) · [验证记录](examples/single-cell/VALIDATION.md) · [许可与来源](examples/single-cell/LICENSE_NOTICE.md) · [同步维护](docs/FORK_MAINTENANCE.zh-CN.md)

## 这个版本提供什么

模板覆盖 UMAP、marker 气泡与热图、细胞比例、表达分布、差异与富集、受配体通讯、网络、拟时序、SCENIC 和空间图。每个包提供 R 入口、最小输入、参数、中文字段说明、PNG/PDF、来源和运行证据。

现有 38 项中，20 项是已有案例结果衍生示例，18 项是合成示例。绘图验证说明见各包记录；模板不会重跑聚类、差异分析、富集、轨迹或通讯推断。SFL 负责资产检索、审阅、发布和材料化，绘图仍由用户或宿主 Agent 执行。

## 先运行一个模板

只使用绘图模板时，需要 Git（或下载源码 ZIP）和 R；不必先启动 SFL。以下命令以 Windows PowerShell 为例。

### 1. 获取这个版本

```powershell
git clone --branch luvega https://github.com/luvega/ScientificFigureLibrary.git
Set-Location ScientificFigureLibrary
```

也可以在 GitHub 选择 `luvega` 分支后，通过 **Code → Download ZIP** 下载并解压。已经有本仓库时不要重复克隆，按 [维护说明](docs/FORK_MAINTENANCE.zh-CN.md) 更新现有副本。上游发布的安装包和 npm 包不等于本 fork 的 38 项模板集合。

### 2. 安装本例所需的 R 包

以 [空间细胞通讯叠加图](examples/single-cell/templates/sc-spatial-communication-overlay/README.md) 为例，在 R 中执行一次：

```r
install.packages(c("ggplot2", "ragg", "yaml"), repos = "https://cloud.r-project.org")
```

然后确认 `Rscript` 可以在终端调用。每个模板的 README 列出自己的依赖；全部模板合计使用 `ComplexHeatmap`、`circlize`、`ggplot2`、`ggrepel`、`igraph`、`patchwork`、`ragg` 和 `yaml`。`ComplexHeatmap` 通过 Bioconductor 安装，其余列出的包通过 CRAN 安装。实际验证版本记录在各包的 `evidence/sessionInfo.txt`；模板代码不会自动安装依赖。

### 3. 复制后运行

在仓库根目录执行，工作副本使用一个尚不存在的目录：

```powershell
$sflRepo = (Get-Location).Path
$plotWork = Join-Path (Split-Path $sflRepo -Parent) "sc-spatial-demo"
if (Test-Path -LiteralPath $plotWork) { throw "工作目录已存在，请更换 plotWork。" }
Copy-Item -LiteralPath "examples/single-cell/templates/sc-spatial-communication-overlay" -Destination $plotWork -Recurse
Set-Location $plotWork
Rscript --vanilla code/plot.R
```

在工作副本中查看 `preview.png` 和 `plot.pdf`。本例为明确标记的合成空间数据，可先核对出图，再替换自己的输入。调用绘图入口时，当前目录必须是包含 `params.yml` 的模板根目录。

## 替换自己的数据与样式

先读所选模板的 `README.md` 和 `data_schema.yml`，再编辑工作副本中的输入和参数：

| 文件 | 用途 |
| --- | --- |
| `data/` | 坐标、表达摘要、边表、矩阵或其他预计算结果 |
| `data_schema.yml` | 必需字段、取值约束、矩阵与注释的对应关系 |
| `params.yml` | 图尺寸、字体、标题、阈值、分面等；选项以各包为准 |
| `code/plot.R` | 从模板根目录运行的统一绘图入口 |
| `adapters/`（如有） | 单独将已有对象或结果表转换为标准输入 |
| `provenance.md`、`evidence/` | 原示例的来源和验证范围 |

空间通讯例子的输入为 `data/nodes.csv`、`data/edges.csv` 和 `data/celltype_colors.csv`。`source`、`target` 对应节点 ID；配体、受体、细胞名称分列保存。坐标方向、分数含义和边的汇总要求见该包说明。

不要把比例分母、表达尺度或排序规则当作纯样式设置。更换数据、代码或参数后，需要重新运行并检查标签、颜色、图例和输出；原包的运行证据只对应原文件，不能当作新数据的验证记录。上游分析和科学结论需要各自验证。

## 可选：使用本版 SFL 管理模板

### 启动本地图库界面

需要 Node.js 22+。回到本仓库根目录后运行：

```powershell
npm ci
npm run build
npm run start:local
```

按启动提示打开本机页面，在界面中明确选择自己的 **Library** 与 **Workspace**。已有图库时继续使用原来的绑定；完整流程见 [用户手册](docs/USER_GUIDE.zh-CN.md)。源码构建使用本 fork 的服务代码，但不会自动将 38 个模板导入 Library。

需要通过 Codex 等宿主使用时，按 [接入说明](docs/QUICKSTART.md) 配置 stdio MCP，将入口指向这个 checkout 的 `dist/index.js`。例如：

```json
{
  "mcpServers": {
    "figure-library": {
      "command": "node",
      "args": ["D:/Tools/ScientificFigureLibrary/dist/index.js"]
    }
  }
}
```

把示例路径替换为自己的绝对路径。已有 `figure-library` 接入时更新原配置，不重复添加第二个服务；构建或配置变化后在新会话加载。

### 将示例收入 Local Published

托管在 GitHub 的模板目录是可运行案例，不会自动注册为 Provider。首次导入某个模板时，可在仓库根目录生成官方 Local candidate：

```powershell
node scripts/private-template-tools.mjs candidate --template examples/single-cell/templates/sc-spatial-communication-overlay --out ../sc-spatial-candidate.local.json
```

输出包含本机资产路径，保留在仓库外的本机工作区。将该 JSON 请求交给 SFL 的 `figure_library_plan_publish`，审阅真实计划、预览和资产后，再通过官方确认流程执行 `figure_library_apply_publish`。已发布的模板无需重复创建；需要更新时明确采用更新模式。不要直接编辑 Library 中的 Release 文件。

转换工具核对证据与资产哈希；证据缺失或文件改变时不会自动声称绘图成功。它保留 `license: unknown`、`distribution: local_only`，不生成审批回执。详细步骤见 [迁移工具说明](docs/PRIVATE_TEMPLATE_MIGRATION.zh-CN.md)。

### 检索、材料化与再次绘图

通过 SFL 检索 Local Published，选择确切模板和 Release，完成预览、确认及材料化。材料化资产保留原样，再准备独立工作副本：

```powershell
node scripts/private-template-tools.mjs work --template "D:/MyProject/materialized/sc-spatial-communication-overlay" --out "D:/MyProject/work/sc-spatial-communication-overlay"
Set-Location "D:/MyProject/work/sc-spatial-communication-overlay"
Rscript --vanilla code/plot.R
```

替换示例路径；`--out` 必须是尚不存在的绝对目录，位于材料化目录之外。工具根据材料化的 `template.json` 等运行映射恢复相对目录并核对哈希；它只准备文件，实际绘图由宿主执行。

## 更新这个版本

本 fork 持续吸收上游更新，同时保留自己的模板、工具和说明。`origin` 是 luvega 的仓库，`upstream` 是原作者的只读更新来源；**默认不向原作者发送 PR**。

维护时比较上游变更、合并到 `luvega`、解决冲突并运行相应验证，再推送本 fork。已撤销的旧功能分支不恢复。具体命令和分支职责见 [Fork 维护说明](docs/FORK_MAINTENANCE.zh-CN.md)。这是维护约定，目前未配置定时同步或无人值守合并。拉取服务更新后需重新构建并重启本地服务或宿主会话，GitHub 更新不会自动替换正在运行的服务。

## 许可、验证和项目来源

- SFL 原项目的作者、许可证和说明保留在仓库中，参见 [LICENSE](LICENSE) 和 [第三方说明](THIRD_PARTY_NOTICES.md)。
- 38 项公开模板的来源许可仍为 `unknown`，不能因其公开可下载或所在仓库的许可证而视作获得新的再分发授权，详见 [模板许可说明](examples/single-cell/LICENSE_NOTICE.md)。
- 已有出图与输入验证见 [验证状态](examples/single-cell/VALIDATION.md)。在仓库根目录运行 `node examples/single-cell/verify.mjs` 可检查资产哈希和证据绑定；该命令不会重新绘图，也不验证科学结论。
- 私有来源资料、完整分析对象、本机图库及审批回执不随本 fork 发布。
