# 1. 输入是真正CSI矩阵，不是AUC或RSS；示例完全合成
source('code/common.R')
library(ComplexHeatmap)
library(circlize)
m <- matrix_from_table(read.csv('data/csi.csv',check.names=FALSE,fileEncoding='UTF-8'))
a <- validate_table(read.csv('data/regulon_annotations.csv',check.names=FALSE,fileEncoding='UTF-8'),c('regulon','module'))
if(nrow(m)!=ncol(m) || !setequal(rownames(m),colnames(m))) stop('CSI must be square with identical row/column identifiers')
m <- m[,rownames(m),drop=FALSE]
if(any(m<0 | m>1)) stop('CSI values must lie in [0,1]')
if(max(abs(m-t(m)))>1e-8 || any(abs(diag(m)-1)>1e-8)) stop('CSI must be symmetric with diagonal equal to 1')
a <- check_annotations(rownames(m),a,'regulon')
if(anyNA(a$module) || any(a$module=='')) stop('provided module labels required')
# 2. 只用输入标签组织两轴，不计算CSI，不重新发现模块
modules <- factor(a$module,levels=unique(a$module))
col_fun <- circlize::colorRamp2(c(0,1),c('#FAF9DA','#28245F'))
colours <- setNames(c('#7DD06F','#844081','#688EC1',grDevices::hcl.colors(nlevels(modules),'Dark 3'))[seq_len(nlevels(modules))],levels(modules))
# 3. 共享两轴身份，保留模块注释和对角线边框
make_plot <- function() {
 top <- HeatmapAnnotation(Module=a$module,col=list(Module=colours),show_annotation_name=FALSE)
 left <- rowAnnotation(Module=a$module,col=list(Module=colours),show_annotation_name=FALSE)
 ht <- Heatmap(m,name='CSI',col=col_fun,top_annotation=top,left_annotation=left,row_split=modules,column_split=modules,
  cluster_rows=FALSE,cluster_columns=FALSE,cluster_row_slices=FALSE,cluster_column_slices=FALSE,row_title=NULL,column_title=NULL,
  show_row_names=isTRUE(params$show_regulon_labels),show_column_names=isTRUE(params$show_regulon_labels),
  row_names_gp=grid::gpar(fontsize=params$font_size-2),column_names_gp=grid::gpar(fontsize=params$font_size-2),column_names_rot=45,
  heatmap_legend_param=list(title='Provided CSI',at=c(0,0.2,0.4,0.6,0.8,1)),border=FALSE,use_raster=FALSE)
 draw(ht,column_title=params$title,column_title_gp=grid::gpar(fontsize=params$font_size+2,fontface='bold'),merge_legends=TRUE,padding=grid::unit(c(10,22,5,8),'mm'))
 for(k in seq_len(nlevels(modules))) decorate_heatmap_body('CSI',{
  grid::grid.rect(gp=grid::gpar(fill=NA,col=params$module_border_colour,lwd=1.5))
 },row_slice=k,column_slice=k)
}
# 4. 显式输出，未经任何CSI统计计算
draw_pair(make_plot)

# 5. 保存本次实际运行环境
writeLines(capture.output(sessionInfo()), "sessionInfo.txt")
cat("OK: preview.png and plot.pdf generated from declared inputs\n")
