source('code/common.R')
library(ggplot2)
d <- validate_table(read.csv('data/expression_summary.csv',check.names=FALSE,fileEncoding='UTF-8'),c('gene','cluster_id','average_expression','percent_expressed'))
require_numeric(d, c('average_expression','percent_expressed'))
if (any(d$percent_expressed < 0 | d$percent_expressed > 100)) stop('percent_expressed must be between 0 and 100')
if (any(d$average_expression < 0)) stop('average_expression must be a non-negative precomputed mean')
if (anyDuplicated(d[c('gene','cluster_id')])) stop('gene/cluster_id pairs must be unique')
ga <- validate_table(read.csv('data/gene_annotations.csv',check.names=FALSE,fileEncoding='UTF-8'),c('gene','marker_celltype','gene_group'))
ca <- validate_table(read.csv('data/cluster_annotations.csv',check.names=FALSE,fileEncoding='UTF-8'),c('cluster_id','celltype','lineage'))
ga <- check_annotations(unique(d$gene), ga, 'gene')
ca <- check_annotations(unique(d$cluster_id), ca, 'cluster_id')
# CSV annotation row order is the explicit visual order, independent of input row order.
ga <- validate_table(read.csv('data/gene_annotations.csv',check.names=FALSE,fileEncoding='UTF-8'),c('gene','marker_celltype','gene_group'))
ca <- validate_table(read.csv('data/cluster_annotations.csv',check.names=FALSE,fileEncoding='UTF-8'),c('cluster_id','celltype','lineage'))
if (nrow(d) != nrow(ga)*nrow(ca)) stop('every gene requires every cluster; missing entries cannot be treated as zeros')
d$x <- match(d$gene,ga$gene); d$y <- nrow(ca)+1-match(d$cluster_id,ca$cluster_id)
mode <- params$expression_scale %||% 'gene_zscore'
if (!mode %in% c('gene_zscore','mean')) stop('expression_scale must be gene_zscore or mean')
d$display_expression <- d$average_expression
if (mode=='gene_zscore') {
  d$display_expression <- ave(d$average_expression,d$gene,FUN=function(z) {
    if (length(z)<2 || sd(z)==0) return(rep(0,length(z)))
    (z-mean(z))/sd(z)
  })
  d$display_expression <- pmax(params$z_min %||% -1, pmin(params$z_max %||% 2,d$display_expression))
}
celltypes <- unique(ca$celltype); lineages <- unique(ca$lineage); groups <- unique(ga$gene_group)
cell_cols <- setNames(rep(c('#d2981a','#a53e1f','#457277','#8f657d','#42819F','#86AA7D','#CBB396'),length.out=length(celltypes)),celltypes)
bg_cols <- setNames(rep(c('#fc8d59','#9e9ac8','#96daf7','#fed976'),length.out=length(lineages)),lineages)
head_cols <- setNames(rep(c('#67161C','#3F6148','#A4804C','#4B5F80'),length.out=length(groups)),groups)
ca$y <- nrow(ca)+1-seq_len(nrow(ca))
bg <- data.frame(xmin=.5,xmax=nrow(ga)+.5,ymin=ca$y-.5,ymax=ca$y+.5,color=bg_cols[ca$lineage])
band <- data.frame(xmin=-.65,xmax=-.15,ymin=ca$y-.5,ymax=ca$y+.5,color=cell_cols[ca$celltype])
blocks <- rle(as.character(ga$gene_group)); ends <- cumsum(blocks$lengths); starts <- c(1,head(ends,-1)+1)
header <- data.frame(xmin=starts-.5,xmax=ends+.5,ymin=nrow(ca)+.62,ymax=nrow(ca)+1.4, label=blocks$values,color=head_cols[blocks$values])
rowblocks <- rle(as.character(ca$celltype)); rends<-cumsum(rowblocks$lengths); rstarts<-c(1,head(rends,-1)+1)
rowlab <- data.frame(x=-.85,y=nrow(ca)+1-(rstarts+rends)/2,label=rowblocks$values)
p <- ggplot() +
  geom_rect(data=bg,aes(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax),fill=bg$color,alpha=.18) +
  geom_rect(data=band,aes(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax),fill=band$color,color='black',linewidth=.25) +
  geom_rect(data=header,aes(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax),fill=header$color,color='white',linewidth=.3) +
  geom_text(data=header,aes(x=(xmin+xmax)/2,y=(ymin+ymax)/2,label=label),color='white',size=3.3) +
  geom_text(data=rowlab,aes(x=x,y=y,label=label),hjust=1,size=3.5) +
  geom_point(data=d,aes(x=x,y=y,size=percent_expressed,color=display_expression)) +
  scale_color_gradientn(colors=c('#FFFFD9','#C7E9B4','#41B6C4','#225EA8','#081D58'),name=if(mode=='gene_zscore') 'Gene z-score\n(clipped)' else 'Mean expression') +
  scale_size_area(max_size=params$dot_max_size %||% 6,limits=c(0,100),breaks=c(25,50,75,100),name='Cells expressing (%)') +
  scale_x_continuous(breaks=seq_len(nrow(ga)),labels=ga$gene,limits=c(-3,nrow(ga)+.55),expand=c(0,0)) +
  scale_y_continuous(breaks=ca$y,labels=ca$cluster_id,limits=c(.5,nrow(ca)+1.5),expand=c(0,0)) +
  labs(x=NULL,y='Cluster',title='Annotated marker expression',subtitle=params$data_label %||% 'Synthetic example') +
  theme_bw(base_size=params$font_size,base_family=params$font_family) +
  theme(panel.grid=element_blank(),panel.border=element_blank(),axis.ticks=element_blank(),
        axis.text.x=element_text(angle=90,hjust=1,vjust=.5,color='black'),axis.text.y=element_text(color='black'),
        plot.margin=margin(8,12,8,8),legend.key.height=grid::unit(.35,'cm'))
save_gg(p)
write.csv(d,'display_values.csv',row.names=FALSE)
writeLines(capture.output(sessionInfo()), 'evidence/sessionInfo.txt')
