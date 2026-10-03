# 1. 预计算二维密度网格；入口不调用KDE或Nebulosa
source('code/common.R')
library(ggplot2)
x <- validate_table(read.csv('data/density_grid.csv',check.names=FALSE,fileEncoding='UTF-8'),c('x','y','density','gene'))
require_numeric(x,c('x','y','density'))
if(anyNA(x$gene) || any(x$gene=='')) stop('gene must be present')
if(anyDuplicated(x[c('gene','x','y')])) stop('gene and coordinate grid keys must be unique')
if(any(x$density<0)) stop('density must be nonnegative')
genes <- unlist(params$gene_order)
if(!setequal(genes,x$gene) || anyDuplicated(genes)) stop('gene_order must match every supplied gene')
gx <- sort(unique(x$x)); gy <- sort(unique(x$y))
if(length(gx)<3 || length(gy)<3) stop('density grid requires at least three points on each axis')
regular <- function(v) max(abs(diff(v)-mean(diff(v)))) <= 1e-7*max(1,abs(mean(diff(v))))
if(!regular(gx) || !regular(gy)) stop('density grid must have evenly spaced coordinates')
for(g in genes) {
 d <- x[x$gene==g,]
 if(nrow(d)!=length(gx)*length(gy) || !setequal(d$x,gx) || !setequal(d$y,gy)) stop('complete shared rectangular density grid required for every gene')
 if(max(d$density)<=0) stop('each gene density grid must contain a positive value')
}
# 2. 保留数值，仅按坐标排序；跨基因共用密度色标
x$gene <- factor(x$gene,levels=genes); x <- x[order(x$gene,x$y,x$x),]
display_max <- params$density_max %||% max(x$density)
if(!is.numeric(display_max) || length(display_max)!=1 || !is.finite(display_max) || display_max<=0 || display_max<max(x$density)) stop('density_max must cover every supplied density value')
if(!is.numeric(params$contour_bins) || params$contour_bins<1 || params$contour_bins%%1!=0) stop('contour_bins must be a positive integer')
# 3. 黑底magma色面，等值线只由已给grid插值，不估计密度
p <- ggplot(x,aes(x,y)) + geom_tile(aes(fill=density),width=mean(diff(gx)),height=mean(diff(gy))) +
 geom_contour(aes(z=density),bins=params$contour_bins,colour='white',linewidth=0.28,alpha=0.6,linetype='dotted') +
 facet_wrap(~gene,nrow=1) + coord_equal(expand=FALSE) +
 scale_fill_gradientn(colours=c('#000004','#3B0F70','#8C2981','#DE4968','#FE9F6D','#FCFDBF'),limits=c(0,display_max),name=params$density_label) +
 labs(title=params$title,subtitle=params$data_label,x='Supplied embedding 1',y='Supplied embedding 2',caption='Precomputed grid values; contours are interpolated isodensity lines') +
 plot_theme() + theme(panel.background=element_rect(fill='black'),strip.background=element_rect(fill='black'),strip.text=element_text(colour='white',face='italic'),panel.spacing=grid::unit(0.35,'lines'))
# 4. 原密度值供复核
dir.create('qa',recursive=TRUE,showWarnings=FALSE)
write.csv(x,'qa/plotted_density.csv',row.names=FALSE,fileEncoding='UTF-8')
write.csv(data.frame(min=0,max=display_max),'qa/colour_limits.csv',row.names=FALSE)

# 5. 明确输出与运行环境
save_gg(p)
writeLines(capture.output(sessionInfo()), 'sessionInfo.txt')
cat('OK: preview.png and plot.pdf generated from declared inputs\n')
