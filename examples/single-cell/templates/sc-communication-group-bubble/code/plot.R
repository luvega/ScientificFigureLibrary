# 1. 已有通讯结果：value和pvalue均由输入提供
source('code/common.R')
library(ggplot2)
x <- validate_table(read.csv('data/communication.csv',check.names=FALSE,fileEncoding='UTF-8'),c('group','source','target','ligand','receptor','value','pvalue'))
require_numeric(x,c('value','pvalue'))
if (any(x$value < 0) || any(x$pvalue < 0 | x$pvalue > 1)) stop('value >= 0 and pvalue in [0,1] required')
keys <- c('group','source','target','ligand','receptor')
if (anyNA(x[keys]) || any(vapply(x[keys], function(v) any(v==''), logical(1)))) stop('pair identifiers must be nonempty')
if (anyDuplicated(x[keys])) stop('duplicate group/source/target/ligand/receptor rows; resolve before plotting')
# 2. 保留缺失与原始零值语义，pvalue截断仅用于显示
floor_p <- params$pvalue_floor %||% 1e-6
if (!is.numeric(floor_p) || floor_p<=0 || floor_p>1) stop('invalid pvalue_floor')
x$logp <- -log10(pmax(x$pvalue,floor_p))
x$group <- factor(x$group,levels=unique(x$group)); x$source <- factor(x$source,levels=unique(x$source)); x$target <- factor(x$target,levels=unique(x$target))
x$pair_label <- paste(x$ligand,x$receptor,sep=' → ')
x$pair_label <- factor(x$pair_label,levels=rev(unique(x$pair_label)))
# 3. group × source 分面；横轴确为target
spectral <- c('#9E0142','#D53E4F','#F46D43','#FDAE61','#FEE08B','#FFFFBF','#E6F598','#ABDDA4','#66C2A5','#3288BD','#5E4FA2')
p <- ggplot(x,aes(target,pair_label)) + geom_point(aes(fill=value,size=logp),shape=21,colour='black',stroke=0.65) +
  facet_grid(group~source,switch='x') +
  scale_fill_gradientn(colours=spectral,name=params$value_label) +
  scale_size_area(max_size=params$max_point_size,name='-log10(pvalue)') +
  scale_x_discrete(position='top',drop=FALSE) +
  labs(x='Target cells',y='Ligand → receptor',title=params$title,
       caption=paste0('Provided CPDB mean/pvalue; pvalue display floor = ',format(floor_p,scientific=TRUE),'; no between-group test')) +
  theme_bw(base_size=params$font_size,base_family=params$font_family) +
  theme(axis.text.x=element_text(angle=90,hjust=0,vjust=0.5),axis.text=element_text(colour='black'),
    strip.text=element_text(face='bold'),strip.background=element_rect(fill='#E8EDF2'),
    panel.spacing=grid::unit(0.12,'cm'),legend.key.height=grid::unit(0.6,'cm'),plot.margin=margin(12,12,12,12))
# 4. 不执行CellChat/CPDB，不补零，直接输出
save_gg(p)

# 5. 保存本次实际运行环境
writeLines(capture.output(sessionInfo()), "sessionInfo.txt")
cat("OK: preview.png and plot.pdf generated from declared inputs\n")
