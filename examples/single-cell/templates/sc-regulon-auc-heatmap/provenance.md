# 来源与改造记录

示例范围：**derived_example**。本目录是维护者确认公开上传的副本；来源许可仍为 **unknown**，见 [许可说明](../../LICENSE_NOTICE.md)。

以下是来源集合中的条目名称与原始内容哈希，用于归属和版本识别；条目不是本仓库的可读取路径。原始归档、完整分析对象和本机定位记录未随副本上传。

- 来源条目：`1-单细胞转录组（scRNA）/3-scRNA转录因子分析（SCENIC）/3-pyscenic R语言版可视化及个性化分析/pySCENIC单细胞转录因子分析及可视化（pyscenic R语言可视化）.R`
  原始内容 SHA256：`d00b7a478c9cb549ea2fc54aaaec2588dec3cc18e79c5af31753689e2237071f`
  保留ComplexHeatmap活性热图结构与显式scale选项，仅提取可视化层。

- 来源条目：`(VIP) 2023-10-26 更新-SCENIC转录因子CSI计算及Module分析及可视化函数/auc.csv`
  原始内容 SHA256：`d6de859998e3d9e47a6a20942c1ca2b1390fcdf94c34f83b9893f4d01f640dd8`
  前80行细胞×指定24列regulon原值转置；未运行AUCell、RSS或CSI。

## 处理范围

- 输入是预计算AUC，不是表达量、RSS或CSI；本接口要求有限[0,1]值。
- scale=raw 原值不变；row_zscore逐regulon减均值除样本标准差，常量行置0。
- 行按CSV给定顺序；列按cells.csv order排序，不自动聚类；细胞ID精确匹配。
- Unannotated是缺少类型注释的标记，不能据此解释细胞群。

PNG/PDF由本包绘图代码生成；上游分析未重跑，科学结论未评估。公开上传不改变原始来源的权利状态。
