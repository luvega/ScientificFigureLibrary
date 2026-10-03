source('code/common.R')
library(ggplot2)
library(patchwork)
library(ggrepel)
d<-validate_table(read.csv('data/differential_results.csv',check.names=FALSE,fileEncoding='UTF-8'),c('comparison','celltype','gene','log2_fc','p_adj'))
require_numeric(d,c('log2_fc','p_adj'))
if(any(d$p_adj<0|d$p_adj>1)) stop('p_adj must be between zero and one')
if(anyDuplicated(d[c('comparison','celltype','gene')])) stop('comparison/celltype/gene rows must be unique')
p_cut<-params$p_adj_threshold %||% .05;fc_cut<-params$log2_fc_threshold %||% .5
if(!is.numeric(p_cut)||!is.finite(p_cut)||p_cut<=0||p_cut>1) stop('p_adj_threshold must be in (0,1]')
if(!is.numeric(fc_cut)||!is.finite(fc_cut)||fc_cut<0) stop('log2_fc_threshold must be nonnegative')
epsilon<-params$zero_p_floor %||% 1e-300
if(!is.numeric(epsilon)||!is.finite(epsilon)||epsilon<=0||epsilon>p_cut) stop('zero_p_floor must be in (0,p_adj_threshold]')
d$significant<-d$p_adj<=p_cut & abs(d$log2_fc)>=fc_cut & d$log2_fc!=0
d$direction<-ifelse(!d$significant,'Not significant',ifelse(d$log2_fc>0,'up','down'))
d$minus_log10_padj<--log10(pmax(d$p_adj,epsilon))
if(any(d$p_adj==0)) warning('p_adj=0 is plotted at the declared zero_p_floor; original values retained')
types<-unique(d$celltype);comparisons<-unique(d$comparison)
cols<-setNames(rep(c('#1F8A42','#272F6F','#EF7E30','firebrick','#7F3C8D','#11A579'),length.out=length(types)),types)
d$celltype<-factor(d$celltype,levels=types);d$comparison<-factor(d$comparison,levels=comparisons)
counts<-expand.grid(comparison=comparisons,celltype=types,direction=c('down','up'),stringsAsFactors=FALSE)
counts$count<-vapply(seq_len(nrow(counts)),function(i) sum(d$comparison==counts$comparison[i]&d$celltype==counts$celltype[i]&d$direction==counts$direction[i]),numeric(1))
counts$signed_count<-ifelse(counts$direction=='up',counts$count,-counts$count)
counts$celltype<-factor(counts$celltype,levels=types);counts$direction<-factor(counts$direction,levels=c('down','up'))
counts$comparison<-factor(counts$comparison,levels=comparisons)
bars<-ggplot(counts,aes(celltype,signed_count,fill=celltype,group=direction))+
 geom_col(position=position_dodge(width=.8),width=.75)+geom_hline(yintercept=0,linewidth=.3)+
 geom_text(aes(label=count,vjust=ifelse(signed_count<0,1.2,-.3)),position=position_dodge(width=.8),size=3)+
 facet_grid(.~comparison)+scale_fill_manual(values=cols)+labs(x=NULL,y='Significant DEGs\nDown / Up')+
 scale_y_continuous(expand=expansion(mult=c(.15,.2)))+plot_theme()+
 theme(legend.position='none',axis.text.x=element_text(color='black',size=9),strip.background=element_blank(),strip.text=element_text(size=params$font_size))
labels<-d[d$significant,,drop=FALSE]
if('label'%in%names(d)){
  labels<-d[d$significant & toupper(as.character(d$label))%in%c('TRUE','1','YES'),,drop=FALSE]
}else{
  n<-params$labels_per_celltype %||% 1
  if(!is.numeric(n)||n<0||n!=floor(n)) stop('labels_per_celltype must be a nonnegative integer')
  labels<-do.call(rbind,lapply(split(labels,interaction(labels$comparison,labels$celltype,drop=TRUE)),function(z) head(z[order(z$p_adj,-abs(z$log2_fc)),],n)))
}
v<-ggplot(d,aes(log2_fc,minus_log10_padj,color=celltype))+
 geom_point(aes(alpha=significant),size=1.5)+scale_alpha_manual(values=c('FALSE'=.2,'TRUE'=.85),guide='none')+
 geom_vline(xintercept=c(-fc_cut,fc_cut),linetype=2,color='grey55',linewidth=.35)+
 geom_hline(yintercept=-log10(p_cut),linetype=2,color='grey55',linewidth=.35)+
 scale_color_manual(values=cols,name='Cell type')+facet_grid(.~comparison)+
 labs(x='Log2(fold change)',y='−Log10(adjusted P)',subtitle=sprintf('%s; adjusted P ≤ %g and |log2FC| ≥ %g',params$data_label %||% 'Synthetic example',p_cut,fc_cut))+
 plot_theme()+theme(strip.text=element_blank(),strip.background=element_blank(),legend.position='right')
if(!is.null(labels)&&nrow(labels)) v<-v+geom_text_repel(data=labels,aes(label=gene),color='black',size=3,fontface='italic',seed=20261002,max.overlaps=Inf)
save_gg((bars/v)+plot_layout(heights=c(.35,1)))
write.csv(d,'classified_results.csv',row.names=FALSE);write.csv(counts,'deg_counts.csv',row.names=FALSE)
writeLines(capture.output(sessionInfo()),'evidence/sessionInfo.txt')
