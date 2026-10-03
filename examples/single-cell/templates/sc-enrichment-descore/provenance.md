# 来源与改造记录

示例范围：**derived_example**。本目录是维护者确认公开上传的副本；来源许可仍为 **unknown**，见 [许可说明](../../LICENSE_NOTICE.md)。

以下是来源集合中的条目名称与原始内容哈希，用于归属和版本识别；条目不是本仓库的可读取路径。原始归档、完整分析对象和本机定位记录未随副本上传。

- 来源条目：`A1ae3b930480d::复现Nature富集DEscore及可视化.R`
  原始内容 SHA256：`6f8935554a55705dc139a70f4c3fc36e625ce434957d8b6b351ae2774fdd3684`
  2024-4-5可视化部分；保留棒棒糖与侧注释色条，删除上游FindMarkers/enrichment。

- 来源条目：`_绘图skill整理/解压/教程/A1ae3b930480d_(VIP) 2024-4-5 复现Nature富集DEscore及可视化.zip/DEscore.csv`
  原始内容 SHA256：`e9ce5493e17ea3945f8fd1cbce63dbe75d051d6437d4d3ee0f1df0c3fc8ad28c`
  预计算15行DEscore结果原值；采用声明的字段重命名。

- 来源条目：`_绘图skill整理/解压/教程/A1ae3b930480d_(VIP) 2024-4-5 复现Nature富集DEscore及可视化.zip/1.png`
  原始内容 SHA256：`c5602fa3abdcd7743985bcb6b2442d9f79faf16e8789d9f88d6e6e2d7e97bd10`
  已实际查看来源图；原固定Macrophage标注错误已按输入表修正。

## 处理范围

- 保留原DEscore.csv全部15行及文件顺序；不重新计算差异表达、GO富集或qvalue。
- DEscore=(up_count-down_count)/all_count，all_count=up_count+down_count；检查原值在1e-6内一致。
- 分组与celltype分列保存；Macrophage按真实原表标注，纠正来源图中将该块写为Neutrophil的固定文字。
- 横坐标=-log10(提供qvalue)，qvalue=0仅显示时使用参数下限；气泡面积编码上下调成员总数，不是背景基因数。
- 此有符号汇总表示通路差异基因的方向比例，不证明整个通路活性或因果效应。

PNG/PDF由本包绘图代码生成；上游分析未重跑，科学结论未评估。公开上传不改变原始来源的权利状态。
