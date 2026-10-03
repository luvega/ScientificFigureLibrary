# 绘图层：矢量必须已经投影到所给嵌入坐标，不计算RNA velocity。
source('code/common.R')
library(ggplot2)
cells <- validate_table(read.csv('data/cells.csv',check.names=FALSE,fileEncoding='UTF-8'),c('cell_id','x','y','celltype'))
vectors <- validate_table(read.csv('data/vectors.csv',check.names=FALSE,fileEncoding='UTF-8'),c('vector_id','x','y','dx','dy'))
require_numeric(cells,c('x','y'));require_numeric(vectors,c('x','y','dx','dy'))
if(anyDuplicated(cells$cell_id) || anyDuplicated(vectors$vector_id))stop('cell and vector identifiers must be unique')
if(anyNA(cells[c('cell_id','celltype')]) || anyNA(vectors$vector_id) || any(cells$cell_id=='' | cells$celltype=='') || any(vectors$vector_id==''))stop('cell/vector identifiers and celltypes must be present')
if(!is.numeric(params$vector_scale) || length(params$vector_scale)!=1 || !is.finite(params$vector_scale) || params$vector_scale<=0)stop('vector_scale must be positive')
if(!any(abs(vectors$dx)+abs(vectors$dy)>0))stop('at least one nonzero vector is required')
vectors$xend <- vectors$x+params$vector_scale*vectors$dx;vectors$yend <- vectors$y+params$vector_scale*vectors$dy
levels <- unique(cells$celltype);palette <- setNames(c('#E6A200','#28A48B','#58A7D8',grDevices::hcl.colors(length(levels),'Dark 3'))[seq_along(levels)],levels)
p <- ggplot()+geom_point(data=cells,aes(x,y,colour=celltype),size=params$cell_point_size,alpha=0.6)+
 geom_segment(data=vectors,aes(x=x,y=y,xend=xend,yend=yend),arrow=grid::arrow(length=grid::unit(params$arrow_length_mm,'mm'),type='closed'),linewidth=params$arrow_linewidth,colour='grey25')+
 scale_colour_manual(values=palette,name='Provided celltype')+coord_equal()+labs(title=params$title,x='Provided embedding x',y='Provided embedding y',caption=paste0('Synthetic projected vectors; displayed endpoint = origin + ',params$vector_scale,' × displacement; no velocity estimation'))+
 plot_theme()+theme(legend.position='right')
save_gg(p)
writeLines(capture.output(sessionInfo()),'sessionInfo.txt')
cat('OK: supplied vectors rendered without estimating velocity\n')
