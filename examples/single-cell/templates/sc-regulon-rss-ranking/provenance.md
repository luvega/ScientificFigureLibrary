# 来源与改造记录

示例范围：**synthetic**。本目录是维护者确认公开上传的副本；来源许可仍为 **unknown**，见 [许可说明](../../LICENSE_NOTICE.md)。

以下是来源集合中的条目名称与原始内容哈希，用于归属和版本识别；条目不是本仓库的可读取路径。原始归档、完整分析对象和本机定位记录未随副本上传。

- 来源条目：`1-单细胞转录组（scRNA）/3-scRNA转录因子分析（SCENIC）/3-pyscenic R语言版可视化及个性化分析/pySCENIC单细胞转录因子分析及可视化（pyscenic R语言可视化）.R`
  原始内容 SHA256：`d00b7a478c9cb549ea2fc54aaaec2588dec3cc18e79c5af31753689e2237071f`
  原脚本291–330行RSS rank风格：蓝底点、红色top6、repel标签；删除calcRSS分析依赖。

## 处理范围

- RSS是预计算specificity score，输入值不做zscore，不重算RSS。
- 每celltype内rss降序，平分时按regulon完整字符串升序，排名从1开始。
- top_n只控制标注数量，不筛选显著性；不生成pvalue。
- 每celltype/regulon唯一；各细胞类型须具有相同regulon集合，避免比较不同候选全集。

PNG/PDF由本包绘图代码生成；上游分析未重跑，科学结论未评估。公开上传不改变原始来源的权利状态。
