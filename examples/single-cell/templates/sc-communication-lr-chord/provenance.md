# 来源与改造记录

示例范围：**derived_example**。本目录是维护者确认公开上传的副本；来源许可仍为 **unknown**，见 [许可说明](../../LICENSE_NOTICE.md)。

以下是来源集合中的条目名称与原始内容哈希，用于归属和版本识别；条目不是本仓库的可读取路径。原始归档、完整分析对象和本机定位记录未随副本上传。

- 来源条目：`(VIP) 2024-11-7 【改装函数】弦图可视化cellphonedb细胞互作结果/ks_comm_chordDiagram.R`
  原始内容 SHA256：`not recorded`
  保留分组定向弦图结构；避免用下划线拆分复合物，新增明确权重语义。

- 来源条目：`(VIP) 2024-11-7 【改装函数】弦图可视化cellphonedb细胞互作结果/cpdb_pbmc_summary.txt`
  原始内容 SHA256：`not recorded`
  已有预计算PBMC结果，只选显著的APP/CD74配对；4条边从Dendritic指向NK、CD14 Monocytes、Dendritic、B。没有重跑通讯分析。

## 处理范围

- source/target/ligand/receptor保持分列，不拆分实体名称
- value采用输入mean；不作因果或实际信号传递判断
- pvalue仅用于显式阈值过滤，不重新检验
- 同细胞类型同基因节点合并，权重按原始边表传入

PNG/PDF由本包绘图代码生成；上游分析未重跑，科学结论未评估。公开上传不改变原始来源的权利状态。
