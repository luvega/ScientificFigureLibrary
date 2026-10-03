# 来源与改造记录

示例范围：**synthetic**。本目录是维护者确认公开上传的副本；来源许可仍为 **unknown**，见 [许可说明](../../LICENSE_NOTICE.md)。

以下是来源集合中的条目名称与原始内容哈希，用于归属和版本识别；条目不是本仓库的可读取路径。原始归档、完整分析对象和本机定位记录未随副本上传。

- 来源条目：`2025-07-KS-account-codes/1-单细胞转录组（scRNA）/6-TCR-BCR分析/2023-8-2 scRepertoire单细胞免疫组库分析.zip!12. 2023-8-2 scRepertoire单细胞免疫组库分析/scRepertoire免疫组库.R`
  原始内容 SHA256：`e1f00ec27b4a3299f6e6bbcbbf825f9dcca2bb260a8ff712a96cc6a18f105f95`
  归档成员：`12. 2023-8-2 scRepertoire单细胞免疫组库分析/scRepertoire免疫组库.R`
  703–706行alluvialClonotypes celltype→cloneType为主要样式；不运行combineBCR/TCR或定义克隆。

- 来源条目：`2025-07-KS-account-codes/1-单细胞转录组（scRNA）/6-TCR-BCR分析/2023-8-2 scRepertoire单细胞免疫组库分析.zip!12. 2023-8-2 scRepertoire单细胞免疫组库分析/scRepertoire单细胞免疫组库分析.pdf`
  原始内容 SHA256：`e1f00ec27b4a3299f6e6bbcbbf825f9dcca2bb260a8ff712a96cc6a18f105f95`
  归档成员：`12. 2023-8-2 scRepertoire单细胞免疫组库分析/scRepertoire单细胞免疫组库分析.pdf`
  实际查看PDF第12页中间alluvialClonotypes图；采用彩色细胞类型条带和白色目标节点。

## 处理范围

- 32行固定合成交叉计数；Single/Small/Large/Hyperexpanded仅为预设类别，不由此模板定义大小阈值。
- count是每样本相应celltype×clone_class的同批细胞计数，要求正整数且键唯一；先在外部汇总零记录。
- 宽度在每样本内按count比例缩放，两侧同一条带宽度保持一致；不把跨组类别条带解释为同一细胞的迁移。
- 条带是注释交叉分布；不重新组装VDJ、识别clone_id、推断克隆扩增或轨迹。
- 等效平滑polygon实现无需scRepertoire/ggalluvial，灰白节点和彩色celltype条带参考原图。

PNG/PDF由本包绘图代码生成；上游分析未重跑，科学结论未评估。公开上传不改变原始来源的权利状态。
