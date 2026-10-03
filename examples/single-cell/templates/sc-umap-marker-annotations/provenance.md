# 来源与改造记录

示例范围：**synthetic**。本目录是维护者确认公开上传的副本；来源许可仍为 **unknown**，见 [许可说明](../../LICENSE_NOTICE.md)。

以下是来源集合中的条目名称与原始内容哈希，用于归属和版本识别；条目不是本仓库的可读取路径。原始归档、完整分析对象和本机定位记录未随副本上传。

- 来源条目：`2024-4-15 复现Nature-单细胞UMAP修饰添加celltype及marker基因标注/复现nature单细胞UMAP降维图修饰.R`
  原始内容 SHA256：`not recorded`
  参考淡色点云、编号圆圈、外置marker连线；不运行FindAllMarkers；源对象未提供，坐标是固定种子的合成示例。

- 来源条目：`2024-4-15 复现Nature-单细胞UMAP修饰添加celltype及marker基因标注/marker_genes.csv`
  原始内容 SHA256：`not recorded`
  保留教程已有marker名称作展示标签，不把模拟坐标视为对应实验结果。

## 处理范围

- 嵌入坐标不重新计算
- 编号由celltype稳定排序生成
- 样本量从实际输入行数计算
- 默认各类型最多5个marker；没有对应标签时报错

PNG/PDF由本包绘图代码生成；上游分析未重跑，科学结论未评估。公开上传不改变原始来源的权利状态。
