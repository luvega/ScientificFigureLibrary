# 1. 读取已计算的一维密度，不重跑拟时或KDE
source('code/common.R')
library(ggplot2)
x <- validate_table(read.csv('data/pseudotime_density.csv',check.names=FALSE,fileEncoding='UTF-8'),c('pseudotime','density','celltype'))
if(!'group' %in% names(x)) x$group <- 'All data'
require_numeric(x,c('pseudotime','density'))
for(nm in c('celltype','group')) if(anyNA(x[[nm]]) || any(x[[nm]]=='')) stop('celltype and group must be present')
if(any(x$pseudotime<0)) stop('pseudotime must be nonnegative')
if(any(x$density<0)) stop('density must be nonnegative')
if(anyDuplicated(x[c('group','celltype','pseudotime')])) stop('group celltype and pseudotime keys must be unique')
types <- unlist(params$celltype_order); palette <- unlist(params$celltype_colors)
if(!setequal(types,x$celltype) || anyDuplicated(types)) stop('celltype_order must match every supplied celltype')
if(!setequal(names(palette),types)) stop('named celltype_colors must match celltype_order')
curve_ids <- interaction(x$group,x$celltype,drop=TRUE)
for(rows in split(seq_len(nrow(x)),curve_ids)) {
 d <- x[rows,]
 if(nrow(d)<3 || diff(range(d$pseudotime))<=0 || max(d$density)<=0) stop('every density curve requires three distinct pseudotime points and a positive density')
}
# 2. 仅排序，不按峰值缩放或重新归一化
x$celltype <- factor(x$celltype,levels=types)
x <- x[order(x$group,x$celltype,x$pseudotime),]
# 3. 保留来源叠加密度的透明填充和具名配色；共同纵轴
p <- ggplot(x,aes(pseudotime,density,colour=celltype,fill=celltype,group=celltype)) +
 geom_ribbon(aes(ymin=0,ymax=density),alpha=params$fill_alpha,colour=NA) + geom_line(linewidth=params$line_width) +
 facet_wrap(~group,nrow=1) + scale_fill_manual(values=palette,drop=FALSE) + scale_colour_manual(values=palette,drop=FALSE) +
 scale_y_continuous(expand=expansion(mult=c(0,0.08))) +
 labs(title=params$title,subtitle=params$data_label,x='Supplied pseudotime',y=params$density_label,colour='Cell type',fill='Cell type',caption='Precomputed curves; height is density, not cell count or transition probability') +
 plot_theme() + theme(strip.background=element_blank(),legend.position='bottom')
# 4. 输出绘图实际采用的曲线原值
dir.create('qa',recursive=TRUE,showWarnings=FALSE)
write.csv(x,'qa/plotted_density.csv',row.names=FALSE,fileEncoding='UTF-8')

# 5. 明确输出与运行环境
save_gg(p)
writeLines(capture.output(sessionInfo()), 'sessionInfo.txt')
cat('OK: preview.png and plot.pdf generated from declared inputs\n')
