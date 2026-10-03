# 1. 读取已提供坐标和表达长表
source('code/common.R')
library(ggplot2)
x <- validate_table(read.csv('data/feature_expression.csv',check.names=FALSE,fileEncoding='UTF-8'),c('cell_id','umap_1','umap_2','gene','expression'))
require_numeric(x,c('umap_1','umap_2','expression'))
for(nm in c('cell_id','gene')) if(anyNA(x[[nm]]) || any(x[[nm]]=='')) stop('cell_id and gene must be present')
if(anyDuplicated(x[c('cell_id','gene')])) stop('cell_id and gene pairs must be unique')
if(any(x$expression<0)) stop('expression must be nonnegative')
for(rows in split(seq_len(nrow(x)),x$cell_id)) if(length(unique(x$umap_1[rows]))!=1 || length(unique(x$umap_2[rows]))!=1) stop('coordinates must be consistent for every cell_id')
genes <- unlist(params$gene_order)
if(!setequal(genes,x$gene) || anyDuplicated(genes)) stop('gene_order must match every supplied gene')
cells <- unique(x$cell_id)
if(any(vapply(split(x$cell_id,x$gene),function(v) !setequal(v,cells),logical(1)))) stop('every gene must include the same cells including zero expression')
if(max(x$umap_1)==min(x$umap_1) || max(x$umap_2)==min(x$umap_2)) stop('embedding must span both coordinates')
# 2. 同一数值尺度；不重新降维、不变换表达量
x$gene <- factor(x$gene,levels=genes)
display_max <- params$expression_max %||% max(x$expression)
if(!is.numeric(display_max) || length(display_max)!=1 || !is.finite(display_max) || display_max<=0 || display_max<max(x$expression)) stop('expression_max must cover every supplied expression value')
x <- x[order(x$gene,x$expression,x$cell_id),]
# 3. 低值先画，高值后画，多个基因保留相同坐标范围
p <- ggplot(x,aes(umap_1,umap_2,colour=expression)) + geom_point(size=params$point_size,alpha=0.9) +
 facet_wrap(~gene,nrow=1) + coord_equal() +
 scale_colour_gradientn(colours=c('grey85','#264B9B','#50C878'),limits=c(0,display_max),name=params$expression_label) +
 labs(title=params$title,subtitle=params$data_label,x='UMAP 1 / supplied embedding 1',y='UMAP 2 / supplied embedding 2',caption='Shared expression scale; all supplied cells including zeros are shown') +
 plot_theme() + theme(panel.border=element_rect(fill=NA,colour='black'),strip.background=element_blank(),legend.position='right')
# 4. 保存原表达值、原坐标及共同色标范围
dir.create('qa',recursive=TRUE,showWarnings=FALSE)
write.csv(x,'qa/plotted_expression.csv',row.names=FALSE,fileEncoding='UTF-8')
write.csv(data.frame(min=0,max=display_max),'qa/colour_limits.csv',row.names=FALSE)

# 5. 明确输出与运行环境
save_gg(p)
writeLines(capture.output(sessionInfo()), 'sessionInfo.txt')
cat('OK: preview.png and plot.pdf generated from declared inputs\n')
