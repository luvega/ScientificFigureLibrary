# 1. 读取参数与预计算相关结果
source('code/common.R')
library(ggplot2)
a <- read.csv('data/correlations.csv',check.names=FALSE,fileEncoding='UTF-8',colClasses=c(group='character',gene='character',target='character'))
require_columns(a,c('group','gene','target','rho','pvalue','padj'),'correlations')
require_numeric(a,c('rho','pvalue','padj'))
for(k in c('group','gene','target')) if(any(is.na(a[[k]])|trimws(a[[k]])=='')) stop(k,' identifiers must be nonempty')
if(any(abs(a$rho)>1)) stop('rho must be in [-1,1]')
if(any(a$pvalue<0|a$pvalue>1|a$padj<0|a$padj>1)) stop('pvalue and padj must be in [0,1]')
if(anyDuplicated(a[c('target','group','gene')])) stop('duplicate target/group/gene key')
ordered_ids <- function(provided,ids,label){
 if(is.null(provided))return(unique(ids))
 if(!is.character(provided)||anyDuplicated(provided)||!setequal(provided,unique(ids)))stop(label,' must exactly match input identifiers')
 provided
}
genes<-ordered_ids(params$gene_order,a$gene,'gene_order');groups<-ordered_ids(params$group_order,a$group,'group_order')
max_size<-params$max_bubble_size %||% 6
if(!is.numeric(max_size)||length(max_size)!=1||!is.finite(max_size)||max_size<=0)stop('max_bubble_size must be positive')
# 2. 显式处理符号和阈值边界；不运行相关性或显著性检验
bands<-c('<=0.0001','<=0.001','<=0.01','<=0.05','>0.05')
a$q_band<-ifelse(a$padj<=.0001,bands[1],ifelse(a$padj<=.001,bands[2],ifelse(a$padj<=.01,bands[3],ifelse(a$padj<=.05,bands[4],bands[5]))))
a$direction<-ifelse(a$rho>0,'positive',ifelse(a$rho<0,'negative','zero'))
a$magnitude<-abs(a$rho)
write.csv(a,'evidence/display_correlations.csv',row.names=FALSE)
a$gene<-factor(a$gene,levels=genes);a$group<-factor(a$group,levels=rev(groups));a$q_band<-factor(a$q_band,levels=bands)
# 3. 保留原例红蓝双图例与气泡面积编码
p<-ggplot()+
 geom_point(data=a[a$rho<0,,drop=FALSE],aes(gene,group,size=magnitude,fill=q_band),colour='black',shape=21,stroke=.3)+
 geom_point(data=a[a$rho>0,,drop=FALSE],aes(gene,group,size=magnitude,colour=q_band),shape=16)+
 scale_size_area(max_size=max_size,limits=c(0,1),breaks=c(.25,.5,.75,1),name='|Spearman rho|')+
 scale_fill_manual(values=setNames(c('#333366','#336699','#3399CC','#66CCFF','#CCCCCC'),bands),drop=FALSE,name='Negative correlation\nAdjusted P value')+
 scale_colour_manual(values=setNames(c('#FF6666','#FF9999','#FFCCCC','#FFE6E6','#CCCCCC'),bands),drop=FALSE,name='Positive correlation\nAdjusted P value')+
 scale_x_discrete(drop=FALSE)+scale_y_discrete(drop=FALSE)+
 labs(title=params$title %||% 'Spearman correlation matrix',subtitle=paste(length(groups),'groups;',length(genes),'genes'),x=NULL,y=NULL)+
 theme_bw(base_size=params$font_size,base_family=params$font_family)+
 theme(panel.grid.major.x=element_blank(),panel.grid.minor=element_blank(),axis.text.x=element_text(angle=45,hjust=1,colour='black'),axis.text.y=element_text(colour='black'),axis.ticks=element_blank(),plot.title=element_text(hjust=.5))+
 guides(size=guide_legend(order=1),fill=guide_legend(order=2),colour=guide_legend(order=3))
if(length(unique(a$target))>1)p<-p+facet_wrap(~target)
# 4. 输出实际 PNG/PDF
save_gg(p)
