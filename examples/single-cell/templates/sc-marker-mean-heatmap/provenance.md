# 来源与改造记录

示例范围：**synthetic**。本目录是维护者确认公开上传的副本；来源许可仍为 **unknown**，见 [许可说明](../../LICENSE_NOTICE.md)。

以下是来源集合中的条目名称与原始内容哈希，用于归属和版本识别；条目不是本仓库的可读取路径。原始归档、完整分析对象和本机定位记录未随副本上传。

- 来源条目：`（VIP）2024-10-17 【一键函数】单细胞marker基因平均表达量热图函数/单细胞marker基因平均表达量热图函数.R`
  原始内容 SHA256：`not recorded`
  源码有Seurat5 AggregateExpression被当作平均表达与df_markers全局引用；已改为明确均值输入。

- 来源条目：`（VIP）2024-10-17 【一键函数】单细胞marker基因平均表达量热图函数/1.png`
  原始内容 SHA256：`not recorded`
  实际查看横向热图；保留粉紫色、黑边与顶部marker类型注释。

## 处理范围

- 模板接收真正预计算的均值；不运行 AverageExpression 或 AggregateExpression。
- 默认按基因跨细胞类型计算row z-score，图例明确标注，不能将 z-score 误读为原平均表达。
- 恒定基因的z-score置0并告警；none模式直接显示输入值，需设置input_scale_label。
- 基因注释必须与矩阵行一一匹配、细胞类型注释与列一一匹配，缺失或多余标识均停止。
- horizontal默认显示细胞类型为行、marker基因为列；vertical显示基因为行。

PNG/PDF由本包绘图代码生成；上游分析未重跑，科学结论未评估。公开上传不改变原始来源的权利状态。
