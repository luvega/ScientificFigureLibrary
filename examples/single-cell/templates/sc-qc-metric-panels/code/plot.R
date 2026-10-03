# 1. 参数和已计算的细胞质量指标
source('code/common.R')
library(ggplot2)
x <- validate_table(read.csv('data/qc_metrics.csv',check.names=FALSE,fileEncoding='UTF-8'),c('cell_id','sample_id','group','nFeature_RNA','nCount_RNA','percent_mt'))
require_numeric(x,c('nFeature_RNA','nCount_RNA','percent_mt'))
for(nm in c('cell_id','sample_id','group')) if(anyNA(x[[nm]]) || any(x[[nm]]=='')) stop('QC identifiers must be present')
if(anyDuplicated(x$cell_id)) stop('cell_id must be unique')
if(any(x$nFeature_RNA<0 | x$nCount_RNA<0) || any(x$nFeature_RNA>x$nCount_RNA)) stop('QC counts must be nonnegative and nFeature_RNA <= nCount_RNA')
if(any(x$nFeature_RNA%%1!=0 | x$nCount_RNA%%1!=0)) stop('QC counts must be integers')
if(any(x$percent_mt<0 | x$percent_mt>100)) stop('percent_mt must be between 0 and 100')
if(any(vapply(split(x$group,x$sample_id),function(v) length(unique(v))!=1,logical(1)))) stop('each sample_id must map to one group')
if(any(table(x$sample_id)<2)) stop('at least two cells per sample required for violin density')
samples <- unlist(params$sample_order)
if(!setequal(samples,x$sample_id) || anyDuplicated(samples)) stop('sample_order must contain each sample once')
palette <- unlist(params$group_colors)
if(!setequal(names(palette),x$group)) stop('group_colors must match all supplied groups')
# 2. 仅转成长表，不筛除细胞，不从计数矩阵计算比例
long <- do.call(rbind,lapply(c('nFeature_RNA','nCount_RNA','percent_mt'),function(nm) data.frame(x[c('cell_id','sample_id','group')],metric=nm,value=x[[nm]])))
long$sample_id <- factor(long$sample_id,levels=samples)
long$metric <- factor(long$metric,levels=c('nFeature_RNA','nCount_RNA','percent_mt'))
thresholds <- data.frame(metric=factor(c('nFeature_RNA','nFeature_RNA','nCount_RNA','percent_mt'),levels=levels(long$metric)),value=c(params$feature_min,params$feature_max,params$count_max,params$mt_max))
require_numeric(thresholds,'value')
if(any(thresholds$value<0) || params$feature_min>=params$feature_max || params$mt_max>100) stop('invalid reference thresholds')
# 3. 同一细胞原值小提琴 + 点，虚线仅标出参考阈值
p <- ggplot(long,aes(sample_id,value,fill=group)) +
 geom_violin(scale='width',trim=TRUE,linewidth=0.4,alpha=0.65) +
 geom_point(position=position_jitter(width=0.12,height=0,seed=20261002),size=params$point_size,alpha=0.35,colour='grey20') +
 geom_hline(data=thresholds,aes(yintercept=value),inherit.aes=FALSE,linetype='dashed',colour='#B7453F',linewidth=0.45) +
 facet_wrap(~metric,scales='free_y',nrow=1) + scale_fill_manual(values=palette) +
 labs(title=params$title,subtitle=params$data_label,x='Sample',y='Supplied QC metric',fill='Group',caption='Dashed lines are reference thresholds; every input cell is retained') +
 plot_theme() + theme(axis.text.x=element_text(angle=45,hjust=1),strip.background=element_rect(fill='grey95'),legend.position='bottom')
# 4. 保留实际绘图值供独立核对
dir.create('qa',recursive=TRUE,showWarnings=FALSE)
write.csv(long,'qa/plotted_metrics.csv',row.names=FALSE,fileEncoding='UTF-8')
write.csv(thresholds,'qa/reference_thresholds.csv',row.names=FALSE,fileEncoding='UTF-8')

# 5. 明确输出与运行环境
save_gg(p)
writeLines(capture.output(sessionInfo()), 'sessionInfo.txt')
cat('OK: preview.png and plot.pdf generated from declared inputs\n')
