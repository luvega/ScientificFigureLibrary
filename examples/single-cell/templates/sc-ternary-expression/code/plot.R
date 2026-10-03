# 1. 已给三个非负表达量
source('code/common.R')
library(ggplot2)
x <- validate_table(read.csv('data/expression.csv',check.names=FALSE,fileEncoding='UTF-8'),c('gene','a','b','c'))
require_numeric(x,c('a','b','c'))
if(anyDuplicated(x$gene) || anyNA(x$gene) || any(x$gene=='')) stop('gene IDs must be unique and present')
if(any(as.matrix(x[c('a','b','c')])<0)) stop('ternary components must be nonnegative')
x$total <- rowSums(x[c('a','b','c')]); if(any(x$total<=0)) stop('zero-sum rows cannot be normalized')
# 2. 重心坐标：a左下、b右下、c顶部；仅按行总和归一化
fraction <- as.matrix(x[c('a','b','c')])/x$total
x$x <- fraction[,2]+fraction[,3]/2; x$y <- sqrt(3)*fraction[,3]/2
maxima <- apply(fraction,1,max)
dominant <- max.col(fraction,ties.method='first')
ties <- rowSums(abs(fraction-maxima)<1e-12)>1
labels <- unlist(params$vertex_labels)
if(length(labels)!=3 || anyDuplicated(labels)) stop('three unique vertex_labels required')
x$dominant <- ifelse(ties,'Tie',labels[dominant])
x$dominant <- factor(x$dominant,levels=c(labels,'Tie'))
# 3. 等价三元网格，无额外ggtern依赖
h <- sqrt(3)/2;grid <- data.frame()
for(t in seq(0.2,0.8,by=0.2)) {
 grid <- rbind(grid,data.frame(x=c(0.5*t,t,1-t),y=c(h*t,0,0),xend=c(1-0.5*t,0.5+0.5*t,0.5-0.5*t),yend=c(h*t,h*(1-t),h*(1-t))))
}
border <- data.frame(x=c(0,1,0.5,0),y=c(0,0,h,0))
palette <- setNames(c('#69B7CE','#E4502E','#688EC1','#999999'),c(labels,'Tie'))
p <- ggplot() + geom_segment(data=grid,aes(x=x,y=y,xend=xend,yend=yend),colour='grey85',linewidth=0.4) +
 geom_path(data=border,aes(x,y),linewidth=0.8) +
 geom_point(data=x,aes(x=x,y=y,colour=dominant),size=params$point_size,alpha=0.8) +
 annotate('text',x=c(-0.05,1.05,0.5),y=c(-0.05,-0.05,h+0.05),label=labels,fontface='bold',size=params$font_size/3) +
 annotate('text',x=seq(0.2,0.8,0.2),y=-0.025,label=paste0(seq(20,80,20),'%'),size=params$font_size/4,colour='grey45') +
 scale_colour_manual(values=palette,drop=TRUE,name='Largest relative share') +
 coord_equal(xlim=c(-0.16,1.2),ylim=c(-0.1,h+0.15),expand=FALSE,clip='off') +
 labs(title=params$title,caption='Each row normalized to sum 1; colour is descriptive, not statistical significance') +
 plot_theme() + theme(axis.line=element_blank(),axis.ticks=element_blank(),axis.text=element_blank(),axis.title=element_blank(),
   plot.margin=margin(15,20,15,20),legend.position='right')
# 4. 显式输出
save_gg(p)

# 5. 保存本次实际运行环境
writeLines(capture.output(sessionInfo()), "sessionInfo.txt")
cat("OK: preview.png and plot.pdf generated from declared inputs\n")
