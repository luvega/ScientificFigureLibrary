# 来源与改造记录

示例范围：**derived_example**。本目录是维护者确认公开上传的副本；来源许可仍为 **unknown**，见 [许可说明](../../LICENSE_NOTICE.md)。

以下是来源集合中的条目名称与原始内容哈希，用于归属和版本识别；条目不是本仓库的可读取路径。原始归档、完整分析对象和本机定位记录未随副本上传。

- 来源条目：`（VIP）2024-1-22 cellchat-cellpgonedbV5互作网络图函数/cellphonedbV5网络图函数.R`
  原始内容 SHA256：`9b9a2abab2ba13f1f5f75551e8a14379c696284b5691fc5787677b2d5c4f7bfe`
  保留环形布局、灰色边、自环与细胞类型配色；修正原例按目标列提取所致的方向风险。

- 来源条目：`（VIP）2024-8-17 cellphonedb V5多组受配体分析可视化函数/GO_cpdb/statistical_analysis_pvalues_08_15_2024_132104.txt`
  原始内容 SHA256：`5c5fe3b55d28bf0f64a9d8101f5e55da76542d30bee13a4222d5b31219f85fe7`
  原始pvalue，不重算

- 来源条目：`（VIP）2024-8-17 cellphonedb V5多组受配体分析可视化函数/GO_cpdb/statistical_analysis_means_08_15_2024_132104.txt`
  原始内容 SHA256：`bb21cc37ce1c95a9618c752ef4a755178d1bb1dd8b0d653cb8125974525e6cc0`
  原始CPDB mean，不是CellChat probability

- 来源条目：`（VIP）2024-8-17 cellphonedb V5多组受配体分析可视化函数/WT_cpdb/statistical_analysis_pvalues_08_15_2024_132617.txt`
  原始内容 SHA256：`8648b79bef25229b721b358925f695c571f4e1ea95d2dd53b7d84bbddb074390`
  原始pvalue，不重算

- 来源条目：`（VIP）2024-8-17 cellphonedb V5多组受配体分析可视化函数/WT_cpdb/statistical_analysis_means_08_15_2024_132617.txt`
  原始内容 SHA256：`d7d2bdc5c27b3324c68be4015ca4f0da45b44f599729ba6e09e1cf3c7048a66d`
  原始CPDB mean，不是CellChat probability

## 处理范围

- source→target 按分列字段传入，名称含下划线或竖线也不拆分。
- 过滤采用 value>0 且 pvalue<阈值；同 group/source/target/interaction_id 必须唯一。
- significant_pairs 是过滤后唯一候选记录的计数；sum_value 是同尺度输入 value 的直接求和。
- 缺少边的细胞对不补成显著边；节点颜色和顺序由独立注释给定；固定节点大小。
- 教程子集包含GJA1/GJA1等未由receptor_a/receptor_b标记确定配体—受体方向的候选；箭头只编码输入列顺序，不证明生物信号方向。

PNG/PDF由本包绘图代码生成；上游分析未重跑，科学结论未评估。公开上传不改变原始来源的权利状态。
