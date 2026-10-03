# 预计算嵌入速度矢量图

绘制已有cell坐标与同坐标基准的网格位移向量。模板不估计RNA velocity、不计算流线或重新投影。

用于展示已有RNA velocity或其他模型已投影到嵌入的位移向量，检查给定细胞状态与局部预测向量的空间关系。

数据范围：synthetic。cell_id/x/y/celltype；540个合成细胞。; vector_id/x/y/dx/dy；预计算合成网格位移，非RNA velocity估计。
