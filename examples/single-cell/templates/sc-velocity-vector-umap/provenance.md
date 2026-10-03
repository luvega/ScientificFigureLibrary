# 来源与改造记录

示例范围：**synthetic**。本目录是维护者确认公开上传的副本；来源许可仍为 **unknown**，见 [许可说明](../../LICENSE_NOTICE.md)。

以下是来源集合中的条目名称与原始内容哈希，用于归属和版本识别；条目不是本仓库的可读取路径。原始归档、完整分析对象和本机定位记录未随副本上传。

- 来源条目：`2025-07-KS-account-codes/1-单细胞转录组（scRNA）/2-scRNA 拟时分析/RNA速率/R语言版RNA速率分析/R语言版RNA速率.R`
  原始内容 SHA256：`db03f0f420e8a46021772e314c5754cd5a56e73a77f9849c1c4929583da59618`
  参考116–173行嵌入scatter+arrow；原源码还含RunVelocity/scVelo推断，均未运行。

- 来源条目：`1-单细胞转录组（scRNA）/2-scRNA 拟时分析/RNA速率/R语言版RNA速率分析/R语言版本RNA速率分析（VIP）.pdf`
  原始内容 SHA256：`c86ba0457c23cc77fb5739d7c1546d90ab2f4db827d3406d6383ffa33baa87f2`
  实际查看PDF第6页，两幅tSNE矢量图；保留细胞分类颜色与灰黑网格箭头布局。

## 处理范围

- seed=20261005；细胞、类型、网格位移完全合成；不是由spliced/unspliced估计。
- vectors的x/y/dx/dy必须已经处于cells的同一嵌入坐标基准；vector_id为网格点ID，不需冒充cell_id。
- 显示端点严格为(x+vector_scale*dx,y+vector_scale*dy)，不按长度归一化；零向量保留但至少应有一个非零向量。
- 嵌入矢量只是提供的模型/示例量；不能据此证明分化方向或因果关系。

PNG/PDF由本包绘图代码生成；上游分析未重跑，科学结论未评估。公开上传不改变原始来源的权利状态。
