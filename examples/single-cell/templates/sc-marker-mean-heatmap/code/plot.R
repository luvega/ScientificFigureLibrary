source('code/common.R')
library(ComplexHeatmap)
library(circlize)
m <- matrix_from_table(read.csv('data/mean_expression.csv',check.names=FALSE,fileEncoding='UTF-8'))
ga <- validate_table(read.csv('data/gene_annotations.csv',check.names=FALSE,fileEncoding='UTF-8'),c('gene','marker_celltype'))
ca <- validate_table(read.csv('data/celltype_annotations.csv',check.names=FALSE,fileEncoding='UTF-8'),c('celltype','color'))
check_annotations(rownames(m),ga,'gene'); check_annotations(colnames(m),ca,'celltype')
if (any(!ga$marker_celltype %in% ca$celltype)) stop('unknown marker_celltype annotation')
if (any(!grepl('^#[0-9A-Fa-f]{6}$',ca$color))) stop('celltype colors must be six-digit hexadecimal colors')
# Use precomputed means. AggregateExpression is not a substitute for mean expression.
ga <- ga[order(match(ga$marker_celltype,ca$celltype)),,drop=FALSE]
m <- m[ga$gene,ca$celltype,drop=FALSE]
mode <- params$scale %||% 'row_zscore'
if (!mode %in% c('row_zscore','none')) stop('scale must be row_zscore or none')
constant <- character()
if (mode=='row_zscore') {
  if(ncol(m)<2) stop('row_zscore requires at least two cell types')
  constant <- rownames(m)[apply(m,1,sd)==0]
  m <- t(apply(m,1,function(z) if(sd(z)==0) rep(0,length(z)) else (z-mean(z))/sd(z)))
  rownames(m)<-ga$gene;colnames(m)<-ca$celltype
}
if(length(constant)) warning('constant genes mapped to z-score zero: ',paste(constant,collapse=', '))
cell_cols<-setNames(ca$color,ca$celltype)
orientation<-params$orientation %||% 'horizontal'
if(!orientation %in% c('horizontal','vertical')) stop('orientation must be horizontal or vertical')
border<-if(isTRUE(params$border)) 'black' else NA
palette<-grDevices::colorRampPalette(c('#FFF7F3','#FDE0DD','#FCC5C0','#FA9FB5','#F768A1','#DD3497','#AE017E','#7A0177','#49006A'))(100)
rg<-range(m);if(diff(rg)==0) rg<-rg+c(-.5,.5)
color_fun<-circlize::colorRamp2(seq(rg[1],rg[2],length.out=100),palette)
legend<-if(mode=='row_zscore') 'Mean expression\nrow z-score' else (params$input_scale_label %||% 'Mean expression')
if(orientation=='horizontal'){
  h<-Heatmap(t(m),name=legend,col=color_fun,cluster_rows=FALSE,cluster_columns=FALSE,
       column_split=factor(ga$marker_celltype,levels=ca$celltype),cluster_column_slices=FALSE,
       top_annotation=HeatmapAnnotation(marker_celltype=ga$marker_celltype,col=list(marker_celltype=cell_cols),
          show_annotation_name=FALSE,show_legend=FALSE,border=TRUE,simple_anno_size=grid::unit(3,'mm')),
       show_row_names=TRUE,show_column_names=TRUE,column_names_rot=90,
       row_names_gp=grid::gpar(fontsize=params$font_size),column_names_gp=grid::gpar(fontsize=params$font_size-1),
       column_title_gp=grid::gpar(fontsize=params$font_size-2),column_gap=grid::unit(0,'mm'),
       rect_gp=grid::gpar(col=border,lwd=.7),row_title=params$data_label %||% 'Synthetic example')
}else{
  h<-Heatmap(m,name=legend,col=color_fun,cluster_rows=FALSE,cluster_columns=FALSE,
       row_split=factor(ga$marker_celltype,levels=ca$celltype),cluster_row_slices=FALSE,
       top_annotation=HeatmapAnnotation(celltype=ca$celltype,col=list(celltype=cell_cols),show_annotation_name=FALSE,show_legend=FALSE),
       right_annotation=rowAnnotation(marker_celltype=ga$marker_celltype,col=list(marker_celltype=cell_cols),show_annotation_name=FALSE,show_legend=FALSE),
       row_names_gp=grid::gpar(fontsize=params$font_size),column_names_gp=grid::gpar(fontsize=params$font_size),
       rect_gp=grid::gpar(col=border,lwd=.7),row_gap=grid::unit(0,'mm'),column_title=params$data_label %||% 'Synthetic example')
}
draw_pair(function() ComplexHeatmap::draw(h,heatmap_legend_side='right',padding=grid::unit(c(5,5,5,5),'mm')))
write.csv(data.frame(gene=rownames(m),m,check.names=FALSE),'display_matrix.csv',row.names=FALSE)
writeLines(capture.output(sessionInfo()),'evidence/sessionInfo.txt')
