# 安装与接入 luvega 版

本页安装的是 `luvega/ScientificFigureLibrary` 的 `luvega` 分支。当前以上游 **0.9.2** 为基线；`main` 保留上游代码，定制功能在 `luvega` 中维护。这个网站提供项目说明，图库和绘图环境在自己的电脑上运行。

## 安装前准备

- 安装 Git 和 **Node.js 22 或更新版本**，确认终端可以调用 `git`、`node` 和 `npm`。
- 使用本地图库界面不需要配置模型；通过 MCP 使用时，需要支持 stdio MCP 的外部宿主。
- 要实际重画，还需按所选模板准备 R 或 Python 及依赖。依赖和输入由宿主按项目规则准备；SFL 不安装依赖、不执行绘图代码。

## 从本 fork 源码安装

以下命令以 Windows PowerShell 为例。新安装时执行：

```powershell
git clone --branch luvega https://github.com/luvega/ScientificFigureLibrary.git
Set-Location ScientificFigureLibrary
npm ci
npm run build
```

已有副本时先核对分支和远程地址，按[同步维护说明](../docs/FORK_MAINTENANCE.zh-CN.md)更新。上游发布的安装包、npm 包及上游 `main` 不能代替这里的 fork 源码安装。构建只生成程序，不会自动把仓库里的模板收入自己的 Library。

## 启动本地图库界面

在仓库根目录运行：

```powershell
npm run start:local
```

根据启动提示打开本机页面。首次使用时明确选择全局 **Library（绘图仓库）** 与 **Workspace（本地工作区）**；已有绑定时继续使用自己的目录。Library 保存已发布版本，Workspace 保存待整理与审阅内容，不要把当前项目目录自动当作全局图库。

在界面中浏览、检索、查看精确预览，并按正常计划与确认流程导入或发布。详细界面流程见[用户手册](../docs/USER_GUIDE.zh-CN.md)。本地 App 不内置模型调用或 Agent 任务编排。

## 接入 Codex 等 MCP 宿主

完成构建后，把已有宿主的 stdio MCP 入口指向这个 checkout 的 `dist/index.js`。通用配置示例：

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

把示例路径替换为自己电脑上的绝对路径。已有 `figure-library` 接入时更新原配置，不再添加第二个同名服务。构建或配置变化后，在新宿主会话加载；GitHub 更新不会自动替换正在运行的进程。各宿主入口和完整接入契约见[快速开始](../docs/QUICKSTART.md)。

普通 MCP 宿主可调用 `figure_library_get_skill` 读取同一个核心 Skill 及按需参考文档。MCP App 是可选界面；宿主也可以通过普通 MCP 工具展示候选与完成选择。

## 第一次使用

1. 确认宿主已加载当前服务，读取 Skill，检查 Library 与 Workspace 状态；尚未配置时按官方计划与确认流程绑定用户明确选择的目录。
2. Library 为空时，先整理一个自己有权使用的图与代码，通过审阅与发布流程收入 Local Published。公开模板也需要显式导入，不会自动注册为 Provider。
3. 按[数据类型与作图目的](../docs/REAL_DATA_CASES.zh-CN.md)检索，查看候选图及其来源、输入和验证范围。
4. 选择精确 Provider 和 Release，查看精确预览并取得确认，再审阅并执行材料化计划。
5. 在材料化目录之外准备独立工作副本，由宿主实际运行 R/Python；保存新图、日志、依赖版本与输入哈希，再检查图形。

搜索缩略图不能代替精确预览确认，材料化或工作副本准备成功也不能当作绘图已完成。完整调用顺序见[协议](../docs/PROTOCOL.md)。

## 公开模板与本机真实数据案例

仓库保留[38 个历史公开单细胞模板](../examples/single-cell/README.md)：20 个为已有案例结果衍生示例，18 个为明确标记的合成示例。它们的来源、许可状态及原验证范围保持原样，不能改称真实数据复验。模板列表、图片和数据留在 GitHub 对应目录，本网站不打包这些资产。

本机整理并发布的 **220 个真实数据案例属于私有本机内容**，不随 Git 克隆、网站或公开 fork 分发。安装通用功能不会带来这些案例。使用者可以按[迁移工具说明](../docs/PRIVATE_TEMPLATE_MIGRATION.zh-CN.md)整理自己的合法来源，保留真实样本、字段、数据筛选与执行记录，再走本机发布流程。

只想先运行一个公开模板，可按[项目说明中的模板步骤](../README.luvega.zh-CN.md#先运行一个模板)复制到新目录并运行，不必先启动 SFL。运行历史合成示例只用于了解模板，不能充当真实研究案例的验收依据。

## 后续更新

更新服务源码后重新构建并重启本地客户端或宿主会话。发布模板新版本时使用 SFL 的正式计划、审阅与确认流程，保留旧的不可变 Release；Git 同步不会自动升级已发布资产。仓库、分支及推送规则见[同步维护](../docs/FORK_MAINTENANCE.zh-CN.md)。
