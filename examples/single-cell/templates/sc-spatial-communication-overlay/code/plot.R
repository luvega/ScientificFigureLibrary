# 1. Read provided spatial coordinates and directional communication edges.
library(ggplot2)
source("code/common.R",encoding="UTF-8")
n<-check_input_columns(read.csv("data/nodes.csv",check.names=FALSE,stringsAsFactors=FALSE),c("node_id","sample_id","cell_type","x","y"))
e<-check_input_columns(read.csv("data/edges.csv",check.names=FALSE,stringsAsFactors=FALSE),c("edge_id","source","target","signal","ligand","receptor","weight"))
cmap<-check_input_columns(read.csv("data/celltype_colors.csv",check.names=FALSE,stringsAsFactors=FALSE),c("cell_type","color"))
require_names(n,c("node_id","sample_id","cell_type"));require_unique(n,"node_id","nodes");require_numeric(n,c("x","y"))
if(length(unique(n$sample_id))!=1)stop("spatial overlay requires one sample")
require_names(e,c("edge_id","source","target","signal","ligand","receptor"));require_unique(e,"edge_id","edges");require_unique(e,c("signal","source","target"),"signal/source/target")
require_numeric(e,"weight")
if(any(!e$source %in% n$node_id)||any(!e$target %in% n$node_id))stop("edge endpoints do not match node identifiers")
if(any(e$source==e$target)||any(e$weight<0))stop("invalid self edge or negative weight")
require_names(cmap,c("cell_type","color"));require_unique(cmap,"cell_type","color map")
if(!setequal(cmap$cell_type,unique(n$cell_type))||any(!grepl("^#[0-9A-Fa-f]{6}$",cmap$color)))stop("cell type color map does not match nodes")
if(!params$coordinate_system %in% c("image","cartesian"))stop("coordinate_system must be image or cartesian")
if(is.null(params$coordinate_unit)||!nzchar(params$coordinate_unit)||is.null(params$weight_label)||!nzchar(params$weight_label))stop("coordinate unit and weight label are required")
if(!is.numeric(params$weight_threshold)||length(params$weight_threshold)!=1||!is.finite(params$weight_threshold)||params$weight_threshold<0)stop("invalid weight_threshold")
# 2. Join endpoints by identity; ligand and receptor remain separate complete names.
shown<-e[e$weight>=params$weight_threshold,,drop=FALSE]
shown$x<-n$x[match(shown$source,n$node_id)];shown$y<-n$y[match(shown$source,n$node_id)]
shown$xend<-n$x[match(shown$target,n$node_id)];shown$yend<-n$y[match(shown$target,n$node_id)]
signals<-unique(e$signal)
shown$signal<-factor(shown$signal,levels=signals)
nodes<-do.call(rbind,lapply(signals,function(signal){d<-n;d$signal<-signal;d}))
nodes$signal<-factor(nodes$signal,levels=signals)
colors<-setNames(cmap$color,cmap$cell_type)
# 3. Fixed coordinate ratio and explicit y orientation; no inferred tissue image.
p<-ggplot()+geom_segment(data=shown,aes(x=x,y=y,xend=xend,yend=yend,linewidth=weight),color="grey35",alpha=0.8,arrow=grid::arrow(length=grid::unit(0.16,"inches"),type="closed"))+
 scale_linewidth_continuous(limits=c(0,max(1,e$weight)),range=c(0.2,2.2),name=params$weight_label)+
 geom_point(data=nodes,aes(x,y,color=cell_type),size=5)+geom_text(data=nodes,aes(x,y,label=cell_type),vjust=-1.3,size=3.2)+
 scale_color_manual(values=colors,breaks=cmap$cell_type)+facet_wrap(~signal,ncol=params$facet_columns,drop=FALSE)+coord_equal(clip="off")+
 scale_x_continuous(expand=expansion(mult=0.20))+
 labs(title=params$title,subtitle=paste0("source → target; ",params$coordinate_system," coordinates; ",params$coordinate_unit),x=paste0("x (",params$coordinate_unit,")"),y=paste0("y (",params$coordinate_unit,")"),color="Cell type")+
 theme_bw(base_size=params$font_size,base_family=params$font_family)+theme(panel.grid=element_blank(),legend.position="bottom",plot.margin=margin(10,18,10,18))
if(params$coordinate_system=="image")p<-p+scale_y_reverse(expand=expansion(mult=0.22)) else p<-p+scale_y_continuous(expand=expansion(mult=0.22))
dir.create("evidence",showWarnings=FALSE)
write.csv(shown,"evidence/display-edges.csv",row.names=FALSE);write.csv(n,"evidence/display-nodes.csv",row.names=FALSE)
save_gg(p)
