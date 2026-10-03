# 分组 PPI 基因互作网络

无向互作网络以节点填色表示输入基因分组，节点大小表示展示子图中的连接度，灰色线宽表示 automated_textmining 分数。标签标出给定度数阈值以上的节点。

- 展示已导出的 STRING 等互作结果与独立基因分组。
- 查看分组节点之间的连接及高连接度节点；互作支持分数不解释为结合强度或因果作用。

数据范围：derived_example。来源 gene_group.csv 150 个基因，string_interactions.csv 378 条无向边；automated_textmining 原值 0–0.952，分组为 up/down。所有节点按完整 gene ID 关联，未查询 STRING 或重新推断网络。
