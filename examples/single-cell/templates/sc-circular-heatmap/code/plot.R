# 1. 原始矩阵与只用于排版的扇区
source('code/common.R')
library(circlize)
library(ComplexHeatmap)
m <- matrix_from_table(read.csv('data/expression.csv',check.names=FALSE,fileEncoding='UTF-8'))
a <- validate_table(read.csv('data/row_annotations.csv',check.names=FALSE,fileEncoding='UTF-8'),c('gene','sector'))
a <- check_annotations(rownames(m),a,'gene')
if(anyNA(a$sector) || any(a$sector=='')) stop('sector labels must be present')
# 2. 可选行缩放；常数行明确置0，不重新计算上游分析
if (isTRUE(params$row_zscore)) {
  s <- apply(m,1,stats::sd)
  if(any(s==0)) warning('constant rows are shown as zero after row z-score')
  m <- sweep(m,1,rowMeans(m),'-');m <- sweep(m,1,ifelse(s==0,1,s),'/')
}
sectors <- factor(a$sector,levels=unique(a$sector))
colour_function <- circlize::colorRamp2(c(-params$colour_limit,0,params$colour_limit),c('#003399','white','#CCCC00'))
legend_title <- if(isTRUE(params$row_zscore)) 'Row z-score' else params$value_label
# 3. 两个设备分别初始化、绘制、清理circlize状态
make_plot <- function() {
  circlize::circos.clear()
  on.exit(circlize::circos.clear(),add=TRUE)
  graphics::par(mar=c(1,1,2,1),family=params$font_family,cex=params$font_size/12)
  gaps <- c(rep(8,nlevels(sectors)-1),40)
  circlize::circos.par(start.degree=30,gap.after=gaps,track.margin=c(0.003,0.003),cell.padding=c(0,0,0,0),points.overflow.warning=FALSE)
  circlize::circos.heatmap(m,split=sectors,col=colour_function,cluster=isTRUE(params$cluster_rows),
    clustering.method='ward.D2',distance.method='euclidean',dend.side=if(isTRUE(params$cluster_rows)) 'inside' else 'none',
    dend.track.height=0.09,rownames.side='outside',rownames.cex=params$label_cex,track.height=0.35,cell.border=NA,bg.border='black')
  # rownames与dendrogram也占track；按ylim辨识真正的12样本热图track。
  tracks <- circlize::get.all.track.index()
  heatmap_track <- tracks[vapply(tracks,function(i) {
    lim <- circlize::get.cell.meta.data('ylim',sector.index=levels(sectors)[1],track.index=i)
    isTRUE(all.equal(as.numeric(lim),c(0,ncol(m))))
  },logical(1))]
  if(length(heatmap_track)!=1) stop('could not identify heatmap track')
  circlize::circos.track(track.index=heatmap_track,panel.fun=function(x,y) {
    if(circlize::CELL_META$sector.index == tail(levels(sectors),1)) {
      circlize::circos.text(rep(circlize::CELL_META$cell.xlim[2] + circlize::convert_x(2,'mm'),ncol(m)),
        seq_len(ncol(m))-0.5,rev(colnames(m)),cex=params$sample_label_cex,facing='inside',adj=c(0,0.5))
    }
  },bg.border=NA)
  legend <- ComplexHeatmap::Legend(title=legend_title,col_fun=colour_function,
    at=c(-params$colour_limit,0,params$colour_limit),labels_gp=grid::gpar(fontsize=params$font_size),title_gp=grid::gpar(fontsize=params$font_size))
  ComplexHeatmap::draw(legend,x=grid::unit(0.5,'npc'),y=grid::unit(0.5,'npc'))
  graphics::title(main=params$title,line=0.1,cex.main=1)
}
# 4. 显式输出PNG和PDF
if (!is.numeric(params$colour_limit) || params$colour_limit<=0) stop('colour_limit must be positive')
draw_pair(make_plot)

# 5. 保存本次实际运行环境
writeLines(capture.output(sessionInfo()), "sessionInfo.txt")
cat("OK: preview.png and plot.pdf generated from declared inputs\n")
