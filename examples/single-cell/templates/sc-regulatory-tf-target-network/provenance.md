# 来源与改造记录

示例范围：**derived_example**。本目录是维护者确认公开上传的副本；来源许可仍为 **unknown**，见 [许可说明](../../LICENSE_NOTICE.md)。

以下是来源集合中的条目名称与原始内容哈希，用于归属和版本识别；条目不是本仓库的可读取路径。原始归档、完整分析对象和本机定位记录未随副本上传。

- 来源条目：`_绘图skill整理/解压/教程/Aefcadb6c399f_8-2024-9-23 pyscenic-单细胞转录因子TF-target网络.zip/pyscenic-单细胞转录因子TF-target网络.R`
  原始内容 SHA256：`b893cb5926ca2838ca1d89ca790a0b0495f823f67c8b221130bd589235e107e0`
  来源 2024-9-23；保留分层与 FR 布局、红色连线、TF 三色和斜体 target；修正 target 覆盖 TF 身份和按节点行序配色问题。

- 来源条目：`_绘图skill整理/解压/教程/Aefcadb6c399f_8-2024-9-23 pyscenic-单细胞转录因子TF-target网络.zip/1.png`
  原始内容 SHA256：`659b35ca4d22c7a89c678f0206e26bf7a69c87f9b16f7c2866027caa6e56a954`
  实际查看原图风格

- 来源条目：`_绘图skill整理/解压/教程/Aefcadb6c399f_8-2024-9-23 pyscenic-单细胞转录因子TF-target网络.zip/2.png`
  原始内容 SHA256：`ccbde5e98e3666aa14c61a16448b9187cb4ff6e6438f1bf86b63b7960241bda2`
  实际查看原图风格

- 来源条目：`_绘图skill整理/解压/教程/Aefcadb6c399f_8-2024-9-23 pyscenic-单细胞转录因子TF-target网络.zip/sce.adj.csv`
  原始内容 SHA256：`925fa8595a6b41b16bc59b1c494ea36d12a075c77826737d4d900a25aec4aedf`
  读取预计算原示例表；不重算上游结果

## 处理范围

- 方向严格按 TF→target 字段，不拆分下划线、竖线或连字符。
- importance 是上游 GRN feature importance，非概率或调控效应；值不标准化、不重算。筛选采用严格 importance > threshold。
- TF 与 target 同名时节点角色必须为 TF_target，保持同一节点；不得覆盖 TF 身份。
- 节点注释按 id 精确匹配全部输入端点；order 只控制布局顺序；TF,target 边键必须唯一。
- 默认 uniform 保留原例等宽红线；importance 模式仅映射原值到线宽，阈值和模式均在参数声明。
- 筛选后无连接的注释节点不参与本次布局；绘图边和节点坐标写入 evidence，筛选规则不会改变原输入。

PNG/PDF由本包绘图代码生成；上游分析未重跑，科学结论未评估。公开上传不改变原始来源的权利状态。
