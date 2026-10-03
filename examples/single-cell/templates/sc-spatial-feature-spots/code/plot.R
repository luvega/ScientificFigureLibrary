# 绘图层：只读取预先给出的坐标和数值，不导入或分析Seurat对象。
source('code/common.R')
library(ggplot2)
d <- validate_table(read.csv('data/spots.csv',check.names=FALSE,fileEncoding='UTF-8'),c('sample','spot_id','feature','x','y','value'))
require_numeric(d,c('x','y','value'))
if(anyNA(d[c('sample','spot_id','feature')]) || any(vapply(d[c('sample','spot_id','feature')],function(v)any(v==''),logical(1))))stop('spot identifiers and feature labels must be present')
if(any(d$value<0))stop('feature values must be nonnegative')
if(anyDuplicated(d[c('sample','spot_id','feature')]))stop('duplicate sample/spot/feature keys')
positions <- unique(d[c('sample','spot_id','x','y')])
if(anyDuplicated(positions[c('sample','spot_id')]))stop('spot coordinates must match across features')
d$sample <- factor(d$sample,levels=unique(d$sample));d$feature <- factor(d$feature,levels=unique(d$feature))
p <- ggplot(d,aes(x,y,fill=value))+geom_point(shape=21,colour='grey30',stroke=0.12,size=params$point_size)+
 facet_grid(feature~sample)+scale_fill_gradientn(colours=c('#F2F2F2','#F5C45E','#CC3C2D'),name=params$value_label)+
 coord_equal()+labs(title=params$title,x='Provided spatial x',y='Provided spatial y',caption='Synthetic spots and values; no tissue image, normalization or spatial inference')+
 plot_theme()+theme(panel.grid=element_blank(),axis.text=element_blank(),axis.ticks=element_blank(),axis.line=element_blank(),strip.background=element_rect(fill='grey95',colour=NA),strip.text=element_text(face='bold'))
if(isTRUE(params$reverse_y))p <- p+scale_y_reverse()
save_gg(p)
writeLines(capture.output(sessionInfo()),'sessionInfo.txt')
cat('OK: spatial spots rendered from declared precomputed inputs\n')
