# luvega 中文文档网站

本 fork 的中文项目说明、源码安装、MCP 接入、检索与重画、模板迁移和同步维护发布在 [luvega 文档网站](https://luvega.github.io/ScientificFigureLibrary/)。网站读取 `luvega` 分支的公开说明，原项目 `docs/index.html`、现有站点资源与 `main` 上游基线继续保留。

## 本地构建

需要 Node.js 22+ 和仓库现有依赖，不额外安装网站框架：

```powershell
npm ci
npm run pages:build
```

独立构建脚本为 [`scripts/build-luvega-pages.mjs`](../scripts/build-luvega-pages.mjs)，复用现有 `markdown-it`。结果写入已忽略的 `dist/luvega-pages/`；可以通过普通本地静态服务器检查，也可以打开其中的 `index.html` 阅读。代码复制按钮只在支持剪贴板的安全上下文中显示，正文和导航不依赖 JavaScript。

## 输入与输出边界

构建器只读取以下 5 个 Markdown 文件，渲染为对应页面：

| 公开源文件 | 输出 |
| --- | --- |
| `README.luvega.zh-CN.md` | `index.html` |
| `website/install.zh-CN.md` | `install.html` |
| `docs/REAL_DATA_CASES.zh-CN.md` | `real-data.html` |
| `docs/PRIVATE_TEMPLATE_MIGRATION.zh-CN.md` | `migration.html` |
| `docs/FORK_MAINTENANCE.zh-CN.md` | `maintenance.html` |

静态资源仅复制 `website/site.css`、`website/site.js` 和已公开的 `docs/assets/logo.svg`，另写入 `.nojekyll` 与 `site-manifest.json`。构建只读取 `package.json` 中的版本用于标示当前基线，不复制整个配置。清单记录相对来源文件、输出大小和 SHA256，不含本机绝对路径。

构建器不扫描或递归复制目录，不接受外部输入目录，也不跟随符号链接或 junction。相互引用的站点文档转换为 HTML 链接；其余公开说明、源码和模板链接指向 GitHub `luvega` 分支。文档新增图片需要重新审查并显式加入允许范围，不能自动带入书籍截图或模板图。

网站不携带私有案例、真实研究输入、图形结果、本机图库、R/Python 运行库、来源路径或审批回执。38 个历史公开模板仅链接到原有 GitHub 目录，保留 18 个合成示例、20 个结果衍生示例和原许可状态；本机真实数据案例不随克隆或站点分发。

## 验证与发布

每次构建验证输入文件类型、生成页面的所有本地导航与锚点，并拒绝私有机器路径。代码块由 Markdown 原文转义渲染，不执行其中的命令。网站构建不启动 SFL、不绑定 Library、不运行 R/Python，也不将文档检查等同于模板或科学结论验收。

Pages 工作流仅从 `luvega` 分支构建，并只上传 `dist/luvega-pages/`。GitHub Pages 使用 GitHub Actions 部署；仓库设置、工作流和正式网站可用性需要分别核验。修改网站时同步检查首页、安装命令、Markdown 链接、手机宽度和实际部署结果。

网站文档变更不会更新已经运行的本地服务，也不会发布或改写 Library 中的模板。服务和模板的更新边界见 [同步维护](FORK_MAINTENANCE.zh-CN.md)。
