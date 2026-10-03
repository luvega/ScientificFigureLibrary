# luvega fork 同步维护

本规则用于维护 `luvega/ScientificFigureLibrary`：持续接入原项目更新，并保留自己的模板、工具和说明。除非用户日后明确改变约定，不向 `xuzhougeng/ScientificFigureLibrary` 推送或创建、重开、提交 PR。用户使用入口见 [luvega 版 README](../README.luvega.zh-CN.md)。

## 仓库与分支

| 名称 | 职责 |
| --- | --- |
| `origin` | `https://github.com/luvega/ScientificFigureLibrary.git`；唯一常规推送目标 |
| `upstream` | `https://github.com/xuzhougeng/ScientificFigureLibrary.git`；只读更新来源 |
| `main` | 保留上游基线，通过快进跟随上游 `main`，不加入本地定制提交 |
| `luvega` | 用户定制版与 fork 默认分支，合并上游更新并保留自身改动 |

原 `feat/private-single-cell-migration` 远程分支已撤销，不自动重建。已有定制提交在 `luvega` 中继续维护。Fork 关系和合并上游代码不会自动向原作者提交 PR。

每次涉及版本更新或发布时先检查上游，再按变更范围合并和验证；未约定定时器，不自动启用后台任务或无人值守合并。

## 每个本地 checkout 的配置

先检查远程目标：

```powershell
git remote -v
```

确认 `origin` 指向 luvega。尚无 `upstream` 时添加；已经存在时先核对地址，不重复添加：

```powershell
git remote add upstream https://github.com/xuzhougeng/ScientificFigureLibrary.git
```

明确设置默认推送与 GitHub CLI 目标，并禁用普通的上游远程推送：

```powershell
git remote set-url --push upstream DISABLED
git config remote.pushDefault origin
gh repo set-default luvega/ScientificFigureLibrary
```

`DISABLED` 是不可用的推送目标，保留 `upstream` 的正常读取。没有安装 GitHub CLI 时可跳过 `gh` 命令；使用它时仍在仓库操作中显式指定 `--repo luvega/ScientificFigureLibrary`。这些配置只属于当前 checkout，新克隆需要重新设置；直接使用上游 URL 仍能绕过远程配置，因此“不向上游写入”的项目规则也必须遵守。

## 一次同步的步骤

以下步骤逐段执行。任一步失败都停止并处理原因，不继续推送；未提交的工作先保存，不能覆盖或丢弃用户已有改动。

### 1. 获取变更并比较

```powershell
git status --short --branch
git fetch origin
git fetch upstream
git log --oneline luvega..upstream/main
git diff --stat luvega...upstream/main
```

开始合并前要求工作区干净。阅读本次上游发布说明和差异；没有新增提交时记录“已对齐”，不制造空合并或空版本升级。

### 2. 更新上游基线

```powershell
git switch main
git merge --ff-only origin/main
git merge --ff-only upstream/main
```

`main` 如果已混入定制提交或无法快进，先查明原因并保留现场，不用强制同步覆盖它。

### 3. 合并到自己的版本

```powershell
git switch luvega
git merge --ff-only origin/luvega
git merge upstream/main
```

确认新提交前检查冲突和差异，保留 `examples/single-cell/`、迁移工具、独立使用说明、来源与证据，以及 `AGENTS.md` 的维护约定。不能简单整块选择“上游版本”而删除自己的功能，也不能整块保留旧代码而漏掉上游修复。合并冲突解决后需要完成合并提交。

禁止用 `git reset --hard upstream/main`、`gh repo sync --force`、强推或删除自己的分支来“保持同步”。已经推送的定制历史默认通过 merge 保留，不以重写历史代替合并。

### 4. 验证后推送到 fork

只修改文档时检查相关 Markdown 链接；合并服务代码时运行对应测试，涉及构建或接入时补充构建和 smoke。基线命令如下，按实际改动选择：

```powershell
npm ci
npm run check
node examples/single-cell/verify.mjs
```

模板资产、输入或绘图代码改变时，另外在独立目录重新绘图、检查 PNG/PDF，并更新对应运行证据与清单；哈希核对不能替代实际出图。验证不能读写真实用户图库或绑定状态。

核对推送目标后，只推送本 fork：

```powershell
git remote -v
git push origin main
git push origin luvega
```

如遇远端领先或非快进错误，重新获取并比较，保留双方改动后再合并；不要强推。同步不需要创建 PR，尤其不能把 fork 网络默认建议的上游仓库当作提交目标。

## 更新本机服务与资产

GitHub 推送、拉取代码、本地构建、重启服务和更新已发布模板是不同步骤。需要应用服务代码变化时重新构建，并重启本地客户端或在新宿主会话加载已有接入；不重复创建同名服务。

正式 Library 的 Published Release 保持不可变。新的模板版本继续通过 SFL 的官方计划、审阅与确认流程发布；不为了同步 Git 而重写已有 Release。绘图成功、上游分析验证和科学结论验证分别记录。
