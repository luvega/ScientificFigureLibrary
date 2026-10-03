# 1. 已预处理矩阵和已有注释；不加载Monocle
source('code/common.R')
library(ComplexHeatmap)
library(circlize)
m <- matrix_from_table(read.csv('data/expression.csv',check.names=FALSE,fileEncoding='UTF-8'))
a <- validate_table(read.csv('data/bin_annotations.csv',check.names=FALSE,fileEncoding='UTF-8'),c('bin_id','pseudotime','celltype'))
g <- validate_table(read.csv('data/gene_annotations.csv',check.names=FALSE,fileEncoding='UTF-8'),c('gene','module'))
a <- check_annotations(colnames(m),a,'bin_id');g <- check_annotations(rownames(m),g,'gene')
require_numeric(a,'pseudotime')
if(anyNA(a$celltype) || anyNA(g$module) || any(a$celltype=='') || any(g$module=='')) stop('annotation labels must be present')
# 2. 只按已有拟时序稳定排序，不平滑、不z-score、不发现模块
ord <- order(a$pseudotime,seq_len(nrow(a)));m <- m[,ord,drop=FALSE];a <- a[ord,,drop=FALSE]
modules <- factor(g$module,levels=unique(g$module));celltypes <- unique(a$celltype)
mod_cols <- setNames(grDevices::hcl.colors(nlevels(modules),'Dark 3'),levels(modules))
cell_cols <- setNames(c('#3F6F76','#C65840','#F4CE4B',grDevices::hcl.colors(length(celltypes),'Dark 3'))[seq_along(celltypes)],celltypes)
pt_range <- range(a$pseudotime)
if(diff(pt_range)==0) pt_range <- pt_range+c(-0.5,0.5)
pt_col <- circlize::colorRamp2(pt_range,c('#1A5592','#B83D3D'))
value_col <- circlize::colorRamp2(c(-params$colour_limit,0,params$colour_limit),c('#1A5592','white','#B83D3D'))
# 3. 显式用输入模块与列顺序；主图颜色说明输入量
make_plot <- function() {
 top <- HeatmapAnnotation(Pseudotime=a$pseudotime,Celltype=a$celltype,
   col=list(Pseudotime=pt_col,Celltype=cell_cols),annotation_name_gp=grid::gpar(fontsize=params$font_size),
   annotation_legend_param=list(Pseudotime=list(title='Provided pseudotime'),Celltype=list(title='Provided celltype')))
 left <- rowAnnotation(Module=g$module,col=list(Module=mod_cols),show_annotation_name=FALSE)
 ht <- Heatmap(m,name=params$value_label,col=value_col,top_annotation=top,left_annotation=left,
   row_split=modules,cluster_rows=FALSE,cluster_row_slices=FALSE,cluster_columns=FALSE,
   show_column_names=FALSE,show_row_names=isTRUE(params$show_gene_labels),row_title=NULL,
   row_names_gp=grid::gpar(fontsize=params$font_size),border=FALSE,use_raster=FALSE)
 draw(ht,column_title=params$title,column_title_gp=grid::gpar(fontsize=params$font_size+2,fontface='bold'),
   heatmap_legend_side='right',annotation_legend_side='right',merge_legends=TRUE)
}
# 4. 合成示例明确标注；对设备分别绘制
if(!is.numeric(params$colour_limit) || params$colour_limit<=0) stop('colour_limit must be positive')
draw_pair(make_plot)

# 5. 保存本次实际运行环境
writeLines(capture.output(sessionInfo()), "sessionInfo.txt")
cat("OK: preview.png and plot.pdf generated from declared inputs\n")
