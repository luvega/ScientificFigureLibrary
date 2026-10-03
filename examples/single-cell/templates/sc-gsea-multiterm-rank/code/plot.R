source('code/common.R')
library(ggplot2);library(patchwork)

ranking<-validate_table(read.csv('data/ranking.csv',check.names=FALSE,fileEncoding='UTF-8'),c('gene_id','rank','statistic'),'ranking')
hits<-validate_table(read.csv('data/hits.csv',check.names=FALSE,fileEncoding='UTF-8'),c('pathway_id','gene_id','rank'),'hits')
enrichment<-validate_table(read.csv('data/enrichment.csv',check.names=FALSE,fileEncoding='UTF-8'),c('pathway_id','description','set_size','enrichment_score','nes','p_adjust'),'enrichment')
require_numeric(ranking,c('rank','statistic'));require_numeric(hits,'rank');require_numeric(enrichment,c('set_size','enrichment_score','nes','p_adjust'))
valid_labels<-function(v)all(!is.na(v)&nzchar(trimws(as.character(v))))
if(!valid_labels(ranking$gene_id)||anyDuplicated(ranking$gene_id)||!identical(as.numeric(ranking$rank),as.numeric(seq_len(nrow(ranking))))||any(diff(ranking$statistic)>0))stop('ranking must have unique genes, contiguous ranks and descending statistics')
if(!valid_labels(enrichment$pathway_id)||!valid_labels(enrichment$description)||anyDuplicated(enrichment$pathway_id))stop('enrichment identifiers must be unique and labels present')
if(any(enrichment$set_size<=0|enrichment$set_size!=floor(enrichment$set_size))||any(enrichment$p_adjust<0|enrichment$p_adjust>1)||any(abs(enrichment$enrichment_score)>1)||any(sign(enrichment$enrichment_score)!=sign(enrichment$nes)))stop('invalid stored enrichment ranges or ES/NES direction')
if(!valid_labels(hits$gene_id)||!valid_labels(hits$pathway_id)||anyDuplicated(hits[c('pathway_id','rank')])||any(hits$rank<1|hits$rank>nrow(ranking)|hits$rank!=floor(hits$rank))||!setequal(hits$pathway_id,enrichment$pathway_id))stop('hit ranks and pathway keys do not match ranking/enrichment')
if(any(as.character(hits$gene_id)!=as.character(ranking$gene_id[hits$rank])))stop('hit gene identifiers do not match supplied ranking positions')
hit_counts<-table(factor(hits$pathway_id,levels=enrichment$pathway_id));if(any(as.numeric(hit_counts)!=enrichment$set_size))stop('hit count does not match supplied set_size')
if(!is.numeric(params$font_size)||params$font_size<=0||!is.numeric(params$width)||params$width<=0||!is.numeric(params$height)||params$height<=0||!is.numeric(params$dpi)||params$dpi<72)stop('invalid rendering dimensions or font size')

if(!params$labels_mode %in% c('text','bubble'))stop('labels_mode must be text or bubble')
if(!is.numeric(params$pathway_wrap)||params$pathway_wrap<10||!is.numeric(params$max_bubble_size)||params$max_bubble_size<=0)stop('invalid label wrap or bubble size')
# 保留原文件顺序；正NES在上、负NES在下。排名始终是统计量由高到低。
ordered<-c(enrichment$pathway_id[enrichment$nes>=0],enrichment$pathway_id[enrichment$nes<0]);enrichment<-enrichment[match(ordered,enrichment$pathway_id),]
enrichment$y<-rev(seq_len(nrow(enrichment)));hits$y<-enrichment$y[match(hits$pathway_id,enrichment$pathway_id)];hits$direction<-ifelse(enrichment$nes[match(hits$pathway_id,enrichment$pathway_id)]>=0,'Positive NES','Negative NES')
labels<-vapply(enrichment$description,function(x)paste(strwrap(x,width=params$pathway_wrap),collapse='\n'),character(1));ylim<-c(.4,nrow(enrichment)+.6)
p1<-ggplot(hits,aes(x=rank,xend=rank,y=y-.36,yend=y+.36,colour=direction))+geom_segment(linewidth=.22)+scale_colour_manual(values=c('Positive NES'=params$positive_colour,'Negative NES'=params$negative_colour),name=NULL)+scale_y_continuous(breaks=enrichment$y,labels=labels,limits=ylim,expand=c(0,0))+scale_x_continuous(limits=c(1,nrow(ranking)),expand=c(0,0))+labs(title='Gene-set hit ranks',x='Gene rank: high → low statistic',y=NULL)+theme_bw(base_size=params$font_size,base_family=params$font_family)+theme(panel.grid=element_blank(),legend.position='bottom',axis.ticks.y=element_blank())
side_theme<-theme_void(base_size=params$font_size,base_family=params$font_family)+theme(plot.title=element_text(hjust=.5),plot.margin=margin(5,5,5,5))
base_side<-function(title)ggplot(enrichment,aes(x=1,y=y))+scale_y_continuous(limits=ylim,expand=c(0,0))+scale_x_continuous(limits=c(.3,1.7))+labs(title=title)+side_theme
if(params$labels_mode=='text'){
 p2<-base_side('adjusted P')+geom_text(aes(label=sprintf('%.2e',p_adjust)),size=params$font_size/3.5)
 p3<-base_side('NES')+geom_text(aes(label=sprintf('%.3f',nes)),size=params$font_size/3.5)
}else{
 # 原函数使用自然对数，明确保留该显示尺度；仅显示时对P=0使用声明下限。
 enrichment$display_logp<--log(pmax(enrichment$p_adjust,params$p_display_floor))
 p2<-base_side('-ln(adjusted P)')+geom_point(aes(fill=display_logp,size=set_size),shape=21,colour='grey30')+scale_fill_viridis_c(name='-ln(adjusted P)')+scale_size_area(max_size=params$max_bubble_size,name='Matched set size')
 p3<-base_side('NES')+geom_point(aes(fill=nes,size=set_size),shape=21,colour='grey30')+scale_fill_gradient2(low='#3F90C9',mid='white',high='#90191B',midpoint=0,name='NES')+scale_size_area(max_size=params$max_bubble_size,name='Matched set size')
}
if(!is.numeric(params$p_display_floor)||length(params$p_display_floor)!=1||!is.finite(params$p_display_floor)||params$p_display_floor<=0||params$p_display_floor>1)stop('p_display_floor must be within (0,1]')
p<-p1+p2+p3+plot_layout(widths=c(6,1.1,.8))+plot_annotation(title=params$title,caption='Original first 10 pathways; descending supplied ranking. NES sign colours are enrichment direction, not gene expression values.')
save_gg(p);writeLines(capture.output(sessionInfo()),'sessionInfo.txt')
write.csv(enrichment[c('pathway_id','description','y','nes','p_adjust','set_size')],'evidence/display-order.csv',row.names=FALSE)
cat('OK: supplied hit ranks, NES and adjusted P rendered without GSEA analysis\n')
