# TF–target 候选定向调控网络

分层布局展示已给 TF→target 候选边，彩色转录因子节点与灰色靶基因节点分开呈现。箭头编码输入方向，importance 可用于筛选和可选线宽，不代表因果效应。

- 查看预计算 pySCENIC GRN 边表中选定 TF 的候选靶基因。
- 比较所选 TF 的共享 target 和连接结构；预测权重只按其原方法含义解释。

数据范围：derived_example。原 sce.adj.csv 77,744 行；沿用来源选择 SOX7、SOX15、TAL1 且 importance > 10 后 64 条边、66 个节点。保留原始 importance 与完整名称，不重运行 SCENIC。
