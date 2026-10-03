# UMAP 细胞群与 marker 注释

在已计算的二维嵌入坐标上，用淡色点云、编号中心和外置 marker 标签展示细胞群及其注释。

- 展示单细胞注释结果，使读者同时查看群体位置和注释依据。
- 对比已完成的细胞分群时，核对 marker 标签和细胞类型是否对应。

数据范围：synthetic。每行一个细胞，包含 cell_id、x、y、celltype；另表每行一个 celltype 与 marker 配对。
