source('code/common.R')
library(ggplot2)
library(patchwork)
d<-validate_table(read.csv('data/expression.csv',check.names=FALSE,fileEncoding='UTF-8'),c('cell_id','sample_id','group','gene','expression'))
require_numeric(d,'expression')
if(any(d$expression<0)) stop('expression must be a non-negative normalized expression scale')
if(anyDuplicated(d[c('cell_id','gene')])) stop('cell_id/gene pairs must be unique')
if(any(!nzchar(d$cell_id)|!nzchar(d$sample_id)|!nzchar(d$group)|!nzchar(d$gene))) stop('identifiers cannot be empty')
cell_map<-unique(d[c('cell_id','sample_id','group')]);if(anyDuplicated(cell_map$cell_id)) stop('cell metadata inconsistent between genes')
sample_map<-unique(d[c('sample_id','group')]);if(anyDuplicated(sample_map$sample_id)) stop('each sample must have a single group')
groups<-params$group_order %||% unique(d$group)
if(!setequal(groups,unique(d$group))||anyDuplicated(groups)) stop('group_order must contain all groups exactly once')
genes<-unique(d$gene);threshold<-params$expression_threshold %||% 0
if(nrow(d)!=length(unique(d$cell_id))*length(genes)) stop('all selected cells must have one expression row per gene including zeros')
if(!is.numeric(threshold)||!is.finite(threshold)||threshold<0) stop('expression_threshold must be a finite non-negative number')
d$group<-factor(d$group,levels=groups)
cols<-setNames(rep(c('#FF5744','#208A42','#FCB31A','#5BBCD6','#7F3C8D'),length.out=length(groups)),groups)
sig<-data.frame()
if(file.exists('data/significance.csv')){
 sig<-read.csv('data/significance.csv',check.names=FALSE,fileEncoding='UTF-8')
 if(nrow(sig)){
  require_columns(sig,c('gene','group1','group2','label'))
  if(any(!sig$gene%in%genes|!sig$group1%in%groups|!sig$group2%in%groups|sig$group1==sig$group2)) stop('unknown gene/group or identical comparison groups in significance table')
  if(any(!nzchar(sig$label))) stop('precomputed significance labels cannot be empty')
  if('y_position'%in%names(sig)) require_numeric(sig,'y_position')
 }
}
plots<-list();fractions<-list()
for(g in genes){
 x<-d[d$gene==g,,drop=FALSE]
 if(!setequal(as.character(x$group),groups)) stop('every gene requires every group')
 sample_counts<-table(x$group);if(any(sample_counts<2)) stop('violin density requires at least two cells per gene and group')
 totals<-aggregate(expression~group,x,function(z)c(n=length(z),positive=sum(z>threshold)))
 pct<-data.frame(gene=g,group=as.character(totals$group),n=totals$expression[,'n'],positive=totals$expression[,'positive'])
 pct$fraction<-pct$positive/pct$n;fractions[[g]]<-pct
 pies<-lapply(groups,function(gr){
  f<-pct$fraction[pct$group==gr];pie<-data.frame(state=factor(c('Expressing','Other'),levels=c('Expressing','Other')),value=c(f,1-f))
  ggplot(pie,aes(x='',y=value,fill=state))+geom_col(width=1,color='black',linewidth=.25)+
    coord_polar(theta='y')+scale_fill_manual(values=c(Expressing=unname(cols[gr]),Other='grey80'))+
    theme_void(base_size=params$font_size,base_family=params$font_family)+
    theme(legend.position='none',plot.title=element_text(hjust=.5,size=params$font_size-1))+
    labs(title=sprintf('%s\n%.1f%%',gr,100*f))
 })
 max_exp<-max(x$expression);yspan<-max(1,max_exp)
 p<-ggplot(x,aes(group,expression,fill=group))+
   geom_violin(scale='width',trim=TRUE,color='black',linewidth=.35)+
   scale_fill_manual(values=cols)+labs(x=NULL,y=params$expression_label %||% 'Normalized expression',title=g)+
   theme_bw(base_size=params$font_size,base_family=params$font_family)+
   theme(panel.grid=element_blank(),panel.border=element_rect(color='black',linewidth=.8),legend.position='none',
    axis.text.x=element_text(color='black',face='bold'),axis.text.y=element_text(color='black'),plot.title=element_text(face='bold.italic',hjust=.5))
 if(isTRUE(params$show_cells)) p<-p+geom_point(position=position_jitter(width=.12,height=0,seed=20261002),size=.4,alpha=.3)
 s<-if(nrow(sig)) sig[sig$gene==g,,drop=FALSE] else data.frame()
 if(nrow(s)){
  s$x1<-match(s$group1,groups);s$x2<-match(s$group2,groups)
  if(!'y_position'%in%names(s)) s$y_position<-max_exp+seq_len(nrow(s))*.12*yspan
  if(any(s$y_position<=max_exp)) stop('significance y_position must exceed maximum expression for its gene')
  p<-p+geom_segment(data=s,aes(x=x1,xend=x2,y=y_position,yend=y_position),inherit.aes=FALSE,linewidth=.6)+
    geom_text(data=s,aes(x=(x1+x2)/2,y=y_position+.02*yspan,label=label),inherit.aes=FALSE,size=3.5)
 }
 p<-p+scale_y_continuous(expand=expansion(mult=c(.03,.12)))
 plots[[g]]<-(wrap_plots(pies,nrow=1)/p)+plot_layout(heights=c(.22,1))+
    plot_annotation(title=paste(g,'— synthetic example'),theme=theme(plot.title=element_text(face='bold.italic',hjust=.5)))
}
out<-wrap_plots(plots,ncol=params$ncol %||% 2)+
  plot_annotation(title='Expression distribution and expressing-cell fraction',subtitle=paste(params$data_label %||% 'Synthetic example','; no statistical tests performed'))
save_gg(out)
write.csv(do.call(rbind,fractions),'expression_fractions.csv',row.names=FALSE)
writeLines(capture.output(sessionInfo()),'evidence/sessionInfo.txt')
