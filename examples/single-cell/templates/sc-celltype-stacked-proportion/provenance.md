# 来源与改造记录

示例范围：**synthetic**。本目录是维护者确认公开上传的副本；来源许可仍为 **unknown**，见 [许可说明](../../LICENSE_NOTICE.md)。

以下是来源集合中的条目名称与原始内容哈希，用于归属和版本识别；条目不是本仓库的可读取路径。原始归档、完整分析对象和本机定位记录未随副本上传。

- 来源条目：`(VIP) 2023-9-22单细胞scRNA-scATAC细胞比例堆叠柱状图(函数）/单细胞scRNA-scATAC细胞比例堆叠柱状图.R`
  原始内容 SHA256：`not recorded`
  原源码按celltype跨组rowSums归一；保留为within_celltype并新增明确的默认组内组成。

- 来源条目：`(VIP) 2023-9-22单细胞scRNA-scATAC细胞比例堆叠柱状图(函数）/1.png`
  原始内容 SHA256：`not recorded`
  实际查看堆叠柱、类型彩色点和total柱。

## 处理范围

- within_group默认：x轴是group、填色celltype，分母为该group所有纳入细胞数，各柱之和为1。
- within_celltype：x轴是celltype、填色group，分母为该celltype所有group细胞数，保留原案例归一方向和注释点。
- 组内先合并样本计数再计算比例，是按细胞数加权的pooled composition；不代表等权样本均值或差异丰度检验。
- 缺少组合按计数0补齐，但任何归一分母为0时停止；不丢弃零计数。
- 总览柱在within_group模式中为全体样本的细胞类型组成，在within_celltype模式中为全体细胞的组组成。

PNG/PDF由本包绘图代码生成；上游分析未重跑，科学结论未评估。公开上传不改变原始来源的权利状态。
