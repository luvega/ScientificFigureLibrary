# 1. Read already computed PAGA positions and undirected weights.
library(ggplot2)
source("code/common.R",encoding="UTF-8")
n<-check_input_columns(read.csv("data/nodes.csv",check.names=FALSE,stringsAsFactors=FALSE),c("node_id","x","y","n_cells","group"))
e<-check_input_columns(read.csv("data/edges.csv",check.names=FALSE,stringsAsFactors=FALSE),c("source","target","connectivity"),empty=TRUE)
require_names(n,c("node_id","group"));require_unique(n,"node_id","nodes");require_numeric(n,c("x","y"))
if(!params$node_size_mode %in% c("uniform","n_cells"))stop("invalid node_size_mode")
if(params$node_size_mode=="n_cells"){require_numeric(n,"n_cells");if(any(n$n_cells<=0|n$n_cells!=floor(n$n_cells)))stop("n_cells must be positive integers")}
if(nrow(e)){
 require_names(e,c("source","target"));require_numeric(e,"connectivity")
 if(any(!e$source %in% n$node_id)||any(!e$target %in% n$node_id))stop("edge endpoints do not match node identifiers")
 if(any(e$source==e$target)||any(e$connectivity<0|e$connectivity>1))stop("invalid self edge or connectivity")
 keys<-data.frame(low=pmin(match(e$source,n$node_id),match(e$target,n$node_id)),high=pmax(match(e$source,n$node_id),match(e$target,n$node_id)))
 if(anyDuplicated(keys))stop("duplicate undirected edge")
}
threshold<-params$connectivity_threshold
if(!is.numeric(threshold)||length(threshold)!=1||!is.finite(threshold)||threshold<0||threshold>1)stop("connectivity threshold must be in [0,1]")
groups<-ordered_levels(n$group,params$group_order,"group");colors<-group_palette(groups,params$group_colors)
# 2. Match coordinates by node identity, preserving isolated nodes and input positions.
shown<-e[e$connectivity>=threshold,,drop=FALSE]
shown$x<-n$x[match(shown$source,n$node_id)];shown$y<-n$y[match(shown$source,n$node_id)]
shown$xend<-n$x[match(shown$target,n$node_id)];shown$yend<-n$y[match(shown$target,n$node_id)]
n$group<-factor(n$group,levels=groups)
regions<-do.call(rbind,lapply(groups,function(group){d<-n[n$group==group,,drop=FALSE];if(nrow(d)<3)return(NULL);d[chull(d$x,d$y),,drop=FALSE]}))
# 3. Undirected black links; node area only uses n_cells when actually supplied.
p<-ggplot()
if(isTRUE(params$show_group_regions)&&!is.null(regions))p<-p+geom_polygon(data=regions,aes(x,y,group=group,fill=group),alpha=0.16,color=NA,show.legend=FALSE)
if(nrow(shown))p<-p+geom_segment(data=shown,aes(x=x,y=y,xend=xend,yend=yend,linewidth=connectivity),color="grey25",alpha=0.75)+scale_linewidth_continuous(limits=c(0,1),range=c(0.1,3),name="Connectivity")
if(params$node_size_mode=="n_cells")p<-p+geom_point(data=n,aes(x,y,color=group,size=n_cells))+scale_size_area(max_size=14,name="Provided cell count") else p<-p+geom_point(data=n,aes(x,y,color=group),size=7)
p<-p+geom_text(data=n,aes(x,y,label=node_id),vjust=-1.25,size=3.4)+scale_color_manual(values=colors)+scale_fill_manual(values=colors)+
 coord_equal(clip="off")+scale_x_continuous(expand=expansion(mult=0.18))+scale_y_continuous(expand=expansion(mult=0.18))+
 labs(title=params$title,subtitle=paste0("Undirected connectivity; threshold ",threshold,"; ",if(params$node_size_mode=="uniform")"uniform nodes" else "provided node counts"),color="Provided annotation")+
 theme_void(base_size=params$font_size,base_family=params$font_family)+theme(legend.position="bottom",plot.margin=margin(12,20,12,20))
dir.create("evidence",showWarnings=FALSE)
write.csv(n,"evidence/display-nodes.csv",row.names=FALSE,na="");write.csv(shown,"evidence/display-edges.csv",row.names=FALSE)
save_gg(p)
