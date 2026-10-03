source("code/common.R", encoding="UTF-8")
# 1. 读取独立结果表；完整名称作为唯一键
edges <- validate_table(read.csv("data/edges.csv",check.names=FALSE,fileEncoding="UTF-8",colClasses=c(TF="character",target="character")),c("TF","target","importance"),"edges")
nodes <- validate_table(read.csv("data/nodes.csv",check.names=FALSE,fileEncoding="UTF-8",colClasses=c(id="character",role="character",colour="character")),c("id","role","colour","order"),"nodes")
require_ids(edges,c("TF","target"),"edges"); require_ids(nodes,c("id","role","colour"),"nodes")
require_numeric(edges,"importance"); require_numeric(nodes,"order")
if(any(edges$importance<0)) stop("importance must be nonnegative",call.=FALSE)
if(anyDuplicated(edges[c("TF","target")])) stop("duplicate TF/target edge",call.=FALSE)
nodes <- check_annotations(unique(c(edges$TF,edges$target)),nodes,"id")
if(anyDuplicated(nodes$order)) stop("node order must be unique",call.=FALSE)
expected_role <- ifelse(nodes$id %in% edges$TF,ifelse(nodes$id %in% edges$target,"TF_target","TF"),"Target")
if(any(nodes$role!=expected_role)) stop("node role does not match TF/target identifiers",call.=FALSE)
tryCatch(grDevices::col2rgb(nodes$colour),error=function(e)stop("invalid node colour",call.=FALSE))
threshold <- scalar_number(params$importance_threshold %||% 0,"importance_threshold")
mode <- scalar_choice(params$edge_width_mode %||% "uniform","edge_width_mode",c("uniform","importance"))
layout_mode <- scalar_choice(params$layout %||% "layered","layout",c("layered","fr"))
seed <- scalar_number(params$seed %||% 1,"seed",upper=.Machine$integer.max,integer=TRUE)
target_size <- scalar_number(params$target_label_size %||% 3,"target_label_size",lower=1,upper=12)
tf_size <- scalar_number(params$tf_label_size %||% 4.5,"tf_label_size",lower=1,upper=12)
# 2. 只筛选给定候选；不运行 GRN/SCENIC
shown <- edges[edges$importance>threshold,,drop=FALSE]
if(!nrow(shown))stop("No edges remain after importance filter",call.=FALSE)
nodes <- nodes[nodes$id %in% unique(c(shown$TF,shown$target)),,drop=FALSE]
nodes <- nodes[order(nodes$order),,drop=FALSE]
gr <- igraph::graph_from_data_frame(shown,directed=TRUE,vertices=data.frame(name=nodes$id))
set.seed(seed)
pos <- if(layout_mode=="layered") igraph::layout_with_sugiyama(gr,weights=NA)$layout else igraph::layout_with_fr(gr,weights=NA)
nodes$x <- pos[,1];nodes$y <- pos[,2]
nodes$node_size <- ifelse(nodes$role=="Target",1.5,5.5)
shown$x <- nodes$x[match(shown$TF,nodes$id)]; shown$y <- nodes$y[match(shown$TF,nodes$id)]
shown$xend <- nodes$x[match(shown$target,nodes$id)]; shown$yend <- nodes$y[match(shown$target,nodes$id)]
# 箭头端点略缩短，只调整几何显示，不改输入方向和权重
dx <- shown$xend-shown$x;dy <- shown$yend-shown$y;dd <- sqrt(dx^2+dy^2)
shorten <- if(layout_mode=="layered") .045 else max(diff(range(nodes$x)),diff(range(nodes$y)))*.01
shown$draw_xend <- shown$xend-ifelse(dd>0,shorten*dx/dd,0)
shown$draw_yend <- shown$yend-ifelse(dd>0,shorten*dy/dd,0)
dir.create("evidence",showWarnings=FALSE)
write.csv(shown,"evidence/plotted-edges.csv",row.names=FALSE)
write.csv(nodes,"evidence/node-layout.csv",row.names=FALSE)
# 3. 原例红色候选连线、TF 三色与灰色 target；独立输出双格式
p <- ggplot2::ggplot()+ggplot2::geom_segment(data=shown,ggplot2::aes(x=x,y=y,xend=draw_xend,yend=draw_yend),colour="#F26969",linewidth=.35,alpha=.85,arrow=grid::arrow(length=grid::unit(1.5,"mm"),type="closed"))
if(mode=="importance") p <- ggplot2::ggplot()+ggplot2::geom_segment(data=shown,ggplot2::aes(x=x,y=y,xend=draw_xend,yend=draw_yend,linewidth=importance),colour="#F26969",alpha=.85,arrow=grid::arrow(length=grid::unit(1.5,"mm"),type="closed"))+ggplot2::scale_linewidth_continuous(range=c(.2,1.1),name="GRN importance")
p <- p+ggplot2::geom_point(data=nodes,ggplot2::aes(x=x,y=y,colour=colour,size=node_size),show.legend=FALSE)+ggplot2::scale_colour_identity()+ggplot2::scale_size_identity()
tf_nodes <- nodes[nodes$role!="Target",];target_nodes <- nodes[nodes$role=="Target",]
if(layout_mode=="layered"){
 p <- p+ggplot2::geom_text(data=tf_nodes,ggplot2::aes(x=x,y=y,label=id),fontface="bold",vjust=-1,size=tf_size)+ggplot2::geom_text(data=target_nodes,ggplot2::aes(x=x,y=y,label=id),fontface="italic",angle=45,hjust=1,vjust=1.6,size=target_size)
}else{
 p <- p+ggrepel::geom_text_repel(data=tf_nodes,ggplot2::aes(x=x,y=y,label=id),fontface="bold",size=tf_size,max.overlaps=Inf,seed=seed,box.padding=.4)+ggrepel::geom_text_repel(data=target_nodes,ggplot2::aes(x=x,y=y,label=id),fontface="italic",size=target_size,max.overlaps=Inf,seed=seed,box.padding=.25)
}
p <- p+ggplot2::theme_void(base_size=params$font_size %||% 12,base_family=params$font_family %||% "sans")+ggplot2::theme(plot.margin=ggplot2::margin(30,30,45,55),plot.title=ggplot2::element_text(face="bold"),legend.position="right")+ggplot2::scale_x_continuous(expand=ggplot2::expansion(mult=c(.08,.05)))+ggplot2::scale_y_continuous(expand=ggplot2::expansion(mult=c(.55,.25)))+ggplot2::coord_cartesian(clip="off")+ggplot2::labs(title="Selected TF-target candidates",subtitle=paste(nrow(shown),"directed edges; GRN importance >",threshold),caption="Arrows encode TF → target input; feature importance is not a causal effect.")
save_gg(p)
