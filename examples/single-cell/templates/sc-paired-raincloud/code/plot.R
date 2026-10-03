# 1. 读取样本表；Family.ID 已由适配层映射为 pair_id
source('code/common.R')
library(ggplot2)
a<-read.csv('data/paired_values.csv',check.names=FALSE,fileEncoding='UTF-8',colClasses=c(sample_id='character',donor_id='character',pair_id='character',group='character'))
require_columns(a,c('sample_id','donor_id','pair_id','group','value'),'paired_values')
require_numeric(a,'value')
for(k in c('sample_id','donor_id','pair_id','group'))if(any(is.na(a[[k]])|trimws(a[[k]])==''))stop(k,' identifiers must be nonempty')
if(anyDuplicated(a$sample_id))stop('sample_id must be globally unique')
if(anyDuplicated(a[c('pair_id','group')]))stop('duplicate pair_id/group key')
groups<-params$group_order %||% unique(a$group)
if(!is.character(groups)||length(groups)!=2||anyDuplicated(groups)||!setequal(groups,unique(a$group)))stop('exactly two known groups required in group_order')
tab<-table(a$pair_id,factor(a$group,levels=groups))
if(any(tab!=1))stop('every pair_id must have exactly one sample in each group')
if(any(colSums(tab)<2))stop('raincloud requires at least two complete pairs')
cols<-unlist(params$group_colors %||% c('#E69F00','#009E73'))
if(length(cols)!=2||any(!grepl('^#[0-9A-Fa-f]{6}$',cols)))stop('group_colors requires two six-digit hexadecimal colors')
jitter<-params$pair_jitter %||% .045
if(!is.numeric(jitter)||length(jitter)!=1||!is.finite(jitter)||jitter<0||jitter>.1)stop('pair_jitter must be in [0,0.1]')
ann<-read.csv('data/comparisons.csv',check.names=FALSE,fileEncoding='UTF-8',colClasses=c(group1='character',group2='character',label='character'))
missing<-setdiff(c('group1','group2','y','label'),names(ann));if(length(missing))stop('comparisons missing columns: ',paste(missing,collapse=', '))
if(nrow(ann)){
 require_numeric(ann,'y')
 if(any(!ann$group1%in%groups|!ann$group2%in%groups|ann$group1==ann$group2))stop('comparisons reference unknown or equal groups')
 if(any(is.na(ann$label)|trimws(ann$label)==''))stop('comparison labels must be nonempty')
 ann$x1<-match(ann$group1,groups);ann$x2<-match(ann$group2,groups)
}
# 2. 仅作绘图密度与箱线汇总，不计算 P 值
a$group<-factor(a$group,levels=groups)
pair_order<-unique(a$pair_id)
offsets<-if(length(pair_order)>1)seq(-jitter,jitter,length.out=length(pair_order))else 0
a$plot_x<-match(a$group,groups)+offsets[match(a$pair_id,pair_order)]
clouds<-lapply(seq_along(groups),function(i){
 v<-a$value[a$group==groups[i]]
 d<-stats::density(v,n=256)
 inside<-d$x>=min(v)&d$x<=max(v);d$x<-d$x[inside];d$y<-d$y[inside]
 if(length(d$x)<2){center<-v[1];span<-max(abs(center)*.01,.01);d$x<-c(center-span,center+span);d$y<-c(1,1)}
 side<-if(i==1)-1 else 1;shift<-i+side*.12
 data.frame(x=c(shift,shift+side*.48*d$y/max(d$y),shift),y=c(d$x[1],d$x,tail(d$x,1)),group=groups[i])
})
cloud<-do.call(rbind,clouds)
write.csv(a,'evidence/display_pairs.csv',row.names=FALSE)
write.csv(cloud,'evidence/density_polygons.csv',row.names=FALSE)
write.csv(ann,'evidence/display_comparisons.csv',row.names=FALSE)
# 3. 半密度朝外展开，连线使用两端原始值与一致偏移
p<-ggplot()+geom_polygon(data=cloud,aes(x,y,fill=group,group=group),alpha=.65,colour=NA)+
 geom_line(data=a,aes(plot_x,value,group=pair_id),colour='grey55',linewidth=.4,alpha=.65)+
 geom_boxplot(data=a,aes(x=as.numeric(group),y=value,group=group,fill=group),width=.14,alpha=.6,outlier.shape=NA,linewidth=.55)+
 geom_point(data=a,aes(plot_x,value,colour=group),size=2)+
 scale_fill_manual(values=setNames(cols,groups))+scale_colour_manual(values=setNames(cols,groups))+
 scale_x_continuous(breaks=seq_along(groups),labels=groups,limits=c(.25,2.75))+
 labs(title=params$title %||% 'Paired sample distribution',x=NULL,y=params$y_label %||% 'Supplied value')+
 theme_bw(base_size=params$font_size,base_family=params$font_family)+theme(panel.grid=element_blank(),legend.position='none',axis.text=element_text(colour='black'),plot.title=element_text(hjust=.5))
if(nrow(ann))p<-p+geom_segment(data=ann,aes(x=x1,xend=x2,y=y,yend=y),inherit.aes=FALSE)+geom_text(data=ann,aes(x=(x1+x2)/2,y=y,label=label),inherit.aes=FALSE,vjust=-.6)
# 4. 输出实际 PNG/PDF
save_gg(p)
