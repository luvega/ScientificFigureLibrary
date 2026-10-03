source('code/common.R')
library(ggplot2)
d<-validate_table(read.csv('data/cell_counts.csv',check.names=FALSE,fileEncoding='UTF-8'),c('sample_id','group','celltype','count'))
require_numeric(d,'count')
if(any(d$count<0 | d$count!=floor(d$count))) stop('count must contain non-negative integers')
if(anyDuplicated(d[c('sample_id','group','celltype')])) stop('sample_id/group/celltype rows must be unique')
sample_groups<-unique(d[c('sample_id','group')])
if(anyDuplicated(sample_groups$sample_id)) stop('each sample_id must belong to one group')
if(any(!nzchar(d$sample_id)|!nzchar(d$group)|!nzchar(d$celltype))) stop('sample, group and cell type names cannot be empty')
groups<-unique(d$group);types<-unique(d$celltype)
a<-aggregate(count~group+celltype,d,sum)
grid<-expand.grid(group=groups,celltype=types,stringsAsFactors=FALSE)
a<-merge(grid,a,all.x=TRUE,sort=FALSE);a$count[is.na(a$count)]<-0
mode<-params$normalization %||% 'within_group'
if(!mode %in% c('within_group','within_celltype')) stop('normalization must be within_group or within_celltype')
if(mode=='within_group'){
 a$denominator<-ave(a$count,a$group,FUN=sum);a$category<-a$group;a$fill<-a$celltype
 levels_x<-groups;levels_fill<-types;y_label<-'Cell-type fraction within group';fill_title<-'Cell type'
 if(isTRUE(params$include_total)){
   total<-aggregate(count~celltype,a,sum)
   total$group<-'All samples';total$denominator<-sum(total$count);total$category<-'All samples';total$fill<-total$celltype
   a<-rbind(a,total[,names(a)]);levels_x<-c(levels_x,'All samples')
 }
}else{
 a$denominator<-ave(a$count,a$celltype,FUN=sum);a$category<-a$celltype;a$fill<-a$group
 levels_x<-types;levels_fill<-groups;y_label<-'Group fraction within cell type';fill_title<-'Group'
 if(isTRUE(params$include_total)){
   total<-aggregate(count~group,a,sum)
   total$celltype<-'All cell types';total$denominator<-sum(total$count);total$category<-'All cell types';total$fill<-total$group
   a<-rbind(a,total[,names(a)]);levels_x<-c(levels_x,'All cell types')
 }
}
if(any(a$denominator==0)) stop('zero-total groups or cell types have undefined fractions')
a$fraction<-a$count/a$denominator
if(any(abs(tapply(a$fraction,a$category,sum)-1)>1e-8)) stop('internal fraction sums are not one')
a$category<-factor(a$category,levels=levels_x);a$fill<-factor(a$fill,levels=levels_fill)
colors<-setNames(rep(c('#E69F00','#56B4E9','#009E73','#F0E442','#0072B2','#D55E00','#CC79A7'),length.out=length(levels_fill)),levels_fill)
p<-ggplot(a,aes(category,fraction,fill=fill))+geom_col(width=.88,color='#222222',linewidth=.5)+
 scale_fill_manual(values=colors,name=fill_title)+
 scale_y_continuous(breaks=seq(0,1,.25),labels=function(z)sprintf('%.2f',z),expand=expansion(mult=c(0,.02)))+
 labs(x=NULL,y=y_label,title='Cell composition',subtitle=paste(params$data_label %||% 'Synthetic example','; pooled counts;',mode))+
 plot_theme()+theme(axis.text.x=element_text(angle=90,hjust=1,vjust=.5,color='black'),axis.ticks.x=element_blank(),axis.text.y=element_text(color='black'))
if(mode=='within_celltype'){
 marker<-data.frame(category=factor(types,levels=levels_x),fraction=-.045)
 p<-p+geom_point(data=marker,aes(category,fraction),inherit.aes=FALSE,size=4,
    color=rep(c('#E69F00','#56B4E9','#009E73','#F0E442','#0072B2','#D55E00','#CC79A7'),length.out=length(types)))+
    coord_cartesian(ylim=c(0,1),clip='off')+theme(axis.text.x=element_text(margin=margin(t=18)),plot.margin=margin(8,12,12,8))
}
save_gg(p)
write.csv(a,'proportions.csv',row.names=FALSE)
writeLines(capture.output(sessionInfo()),'evidence/sessionInfo.txt')
