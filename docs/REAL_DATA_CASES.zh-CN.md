# 按数据和目的检索真实数据案例

SFL 管理案例的图片、代码、来源和版本。真实数据案例沿用 Local Published，绘图由宿主 Agent 在独立工作副本执行。私有案例、数据、运行库和审批回执不随公开 fork 分发。

## 在本地界面选图

图库搜索栏提供“数据类型”和“作图目的”。选项来自已发布模板的 `数据类型:`、`作图目的:` 标签，不要求其他 Provider 使用同一套分类。两个条件取交集；“清空分类”恢复全部，包括未分类模板。选项不会根据当前关键词结果消失。

可以先按自己的表结构选择数据类型，再按想回答的问题缩小范围。例如：数值矩阵配“看表达或矩阵模式”；节点和边配“看联系、网络与流向”。进入具体案例后继续核对输入单位、比例分母和结果的适用范围。

## 通过 MCP 检索

`figure_library_search` 与 `figure_library_list_catalog` 接受可选的 `requiredTags`。所有标签须精确满足，处理顺序为去首尾空格、NFC 规范化、去空、去重及排序；大小写保持区分。未传或传空数组时保持原行为。标签来自模板元数据，不能把描述中的近似词命中当作分类匹配。

以 `figure_library_search` 为例：

```json
{
  "query": "",
  "providerIds": ["org.scientificfigurelibrary.local"],
  "requiredTags": ["data-type:numeric_matrix", "purpose:matrix_pattern"],
  "limit": 12
}
```

真实案例集合同时保留机器标签和中文标签；准确值以当前案例元数据为准。例如 `data-type:numeric_matrix`、`purpose:matrix_pattern` 对应数据结构与作图目的；中文标签供本地界面使用。宿主可先读取目录，从返回的真实标签选择条件。请求变更后重新检索，不能沿用其他查询的分页游标。

## 材料化后重新绘图

先选择精确 Provider/Release，查看精确预览并取得确认，再通过材料化计划和执行流程。材料化保存参考资产；`template.json` 的 `content.runtime` 声明入口、依赖和输入之间的映射。不要在不可变参考目录里覆盖作图。

现有运行目录工具可以将 Local Published 材料化资产恢复到一个尚不存在的工作目录：

```powershell
node scripts/private-template-tools.mjs work --template "D:/Project/materialized/selected-template" --out "D:/Project/work/selected-template"
Set-Location "D:/Project/work/selected-template"
Rscript --vanilla code/plot.R
```

实际入口以所选模板的运行声明为准。独立执行器可读取随包的 `host-run.json`：验证输入、参数与代码 SHA256；清除工作副本中的历史同名输出；调用宿主明确配置的 R/Python；保存命令、退出状态、会话包版本、日志和新 PNG/PDF 哈希。执行前后再检查原材料化资产及输入没有变化。依赖由宿主按项目规则准备，SFL 不自动安装或执行代码。

缓存的差异表、富集结果、UMAP 坐标和已拟合对象可以作为真实派生输入；需保留原研究出处、真实样本/供体及筛选或汇总过程。只重画时不要重复调用上游差异、通讯或轨迹推断。运行后检查实际图的坐标、标签、图例、颜色和截断；进程退出成功与科学结论验证分别记录。

## 来源、证据与更新

运行包应携带用途说明、数据字段、原始参考代码、当前执行代码、真实输入、参数、来源清单、原运行证据及新运行证据。完整本机来源位置可保存在私有来源文件中；写入 SFL 元数据时使用来源标识、URL、内容哈希及相对资产引用，避免把绝对路径当作可移植资产身份。

Published Release 保持不可变。将旧合成或历史衍生示例替换为真实版本时，新建 revision/release 并保留旧身份，不能把旧证据改名为真实。绘图执行、上游工作流和科学有效性分别记录。正式发布继续遵循官方计划、一次人审和执行流程；隔离验收中的模拟确认只对测试库有效。

相关说明：[迁移工具](PRIVATE_TEMPLATE_MIGRATION.zh-CN.md)、[协议](PROTOCOL.md)、[用户手册](USER_GUIDE.zh-CN.md)。
