# 来源与改造记录

示例范围：**derived_example**。本目录是维护者确认公开上传的副本；来源许可仍为 **unknown**，见 [许可说明](../../LICENSE_NOTICE.md)。

以下是来源集合中的条目名称与原始内容哈希，用于归属和版本识别；条目不是本仓库的可读取路径。原始归档、完整分析对象和本机定位记录未随副本上传。

- 来源条目：`（VIP）2024-10-29 【函数】复现SCI-cellchat-cpdb-细胞互作受配体分组气泡图函数/cellphonedb V5-细胞互作受配体多组气泡图函数.R`
  原始内容 SHA256：`2c945625d276b129211c45265e7975001c2fc3f94e95e41ef7ec792f1f2e14e6`
  group×source分面、target横轴和LR纵轴布局

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

- source,target,ligand,receptor显式分列
- 缺失记录不补零；pvalue=0仅视觉变换截断
- 不执行通讯分析、不做跨组差异检验
- 横轴准确命名Target cells，避免原例Source cells误标

PNG/PDF由本包绘图代码生成；上游分析未重跑，科学结论未评估。公开上传不改变原始来源的权利状态。
