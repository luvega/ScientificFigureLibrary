# 1. 读取已有边和节点，不构建预测网络
source('code/common.R')
library(ggplot2)
e <- validate_table(read.csv('data/edges.csv',check.names=FALSE,fileEncoding='UTF-8'),c('from','to','weight'))
n <- validate_table(read.csv('data/nodes.csv',check.names=FALSE,fileEncoding='UTF-8'),c('id','side'))
require_numeric(e,'weight')
if (any(e$weight < 0)) stop('edge weights must be nonnegative')
if (anyNA(n) || anyNA(e[c('from','to')]) || any(!n$side %in% c('ligand','target'))) stop('invalid node identifiers/side')
if (anyDuplicated(n[c('id','side')]) || anyDuplicated(e[c('from','to')])) stop('duplicate node or edge identifiers')
# 2. 两侧角色单独匹配；同名实体可在两侧各出现一次
left <- n[n$side=='ligand',,drop=FALSE]; right <- n[n$side=='target',,drop=FALSE]
if(!nrow(left) || !nrow(right)) stop('both sides need nodes')
if(any(!e$from %in% left$id) || any(!e$to %in% right$id)) stop('edge endpoint does not match its declared side')
left$x <- 0;left$y <- if(nrow(left)==1) 0.5 else seq(1,0,length.out=nrow(left))
right$x <- 1;right$y <- if(nrow(right)==1) 0.5 else seq(1,0,length.out=nrow(right))
n <- rbind(left,right)
e$y_from <- left$y[match(e$from,left$id)]; e$y_to <- right$y[match(e$to,right$id)]
# 3. 双重编码权重，无虚构up/down颜色或因果箭头
p <- ggplot() + geom_segment(data=e,aes(x=0,xend=1,y=y_from,yend=y_to,linewidth=weight,colour=weight),lineend='round') +
  geom_point(data=n,aes(x=x,y=y,shape=side),size=3.8,fill='white',colour='black',stroke=0.8) +
  geom_text(data=left,aes(x=-0.06,y=y,label=id),hjust=1,fontface='italic',size=params$font_size/3.1) +
  geom_text(data=right,aes(x=1.06,y=y,label=id),hjust=0,fontface='italic',size=params$font_size/3.1) +
  annotate('text',x=c(0,1),y=1.08,label=c('Ligands','Targets'),fontface='bold',size=params$font_size/3) +
  scale_shape_manual(values=c(ligand=21,target=23)) +
  scale_colour_gradient(low='#D9D9D9',high='#222222',name=params$weight_label) +
  scale_linewidth_continuous(range=c(0.25,1.5),name=params$weight_label) +
  coord_cartesian(xlim=c(-0.4,1.5),ylim=c(-0.04,1.1),clip='off') +
  labs(title=params$title,caption='Provided model weights; edges do not establish direct regulation or causality') +
  plot_theme() + theme(axis.text=element_blank(),axis.ticks=element_blank(),axis.title=element_blank(),axis.line=element_blank(),
    legend.position='right',plot.margin=margin(12,12,12,12)) + guides(shape='none',linewidth='none')
# 4. 显式输出
save_gg(p)

# 5. 保存本次实际运行环境
writeLines(capture.output(sessionInfo()), "sessionInfo.txt")
cat("OK: preview.png and plot.pdf generated from declared inputs\n")
