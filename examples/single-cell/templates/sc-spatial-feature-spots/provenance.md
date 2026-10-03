# 来源与改造记录

示例范围：**synthetic**。本目录是维护者确认公开上传的副本；来源许可仍为 **unknown**，见 [许可说明](../../LICENSE_NOTICE.md)。

以下是来源集合中的条目名称与原始内容哈希，用于归属和版本识别；条目不是本仓库的可读取路径。原始归档、完整分析对象和本机定位记录未随副本上传。

- 来源条目：`2025-07-KS-account-codes/4-空间转录组/10X visum空转分析/2-seurat分析10X空转下游基本流程（数据读取-降维聚类-annotation-基本可视化等）/Seurat分析10X空转下游基本流程.R`
  原始内容 SHA256：`d987a820b8980d53f2aca39afe289e034eb02fb2f3d61fea63750848e9cca2f3`
  源教程以SpatialDimPlot/SpatialFeaturePlot展示spot；只参考239–267行绘图样式，未运行读入、整合或聚类。目录无现成spot坐标+表达小表。

## 处理范围

- seed=20261004；两切片、两特征均为合成；同一spot跨特征坐标必须一致。
- x/y为同一空间坐标基准；reverse_y仅改变显示方向，不归一化或缩放坐标。
- value非负且保持原数值；不运行SCTransform或空间统计。
- 未提供histology image，因此不叠加组织背景。

PNG/PDF由本包绘图代码生成；上游分析未重跑，科学结论未评估。公开上传不改变原始来源的权利状态。
