source("code/common.R", encoding="UTF-8")
# 1. 预计算无向互作边与独立基因注释
edges <- validate_table(read.csv("data/edges.csv",check.names=FALSE,fileEncoding="UTF-8",colClasses=c(from="character",to="character")),c("from","to","automated_textmining"),"edges")
nodes <- validate_table(read.csv("data/nodes.csv",check.names=FALSE,fileEncoding="UTF-8",colClasses=c(gene="character",group="character")),c("gene","group"),"nodes")
require_ids(edges,c("from","to"),"edges");require_ids(nodes,c("gene","group"),"nodes")
require_numeric(edges,"automated_textmining")
if(any(edges$automated_textmining<0 | edges$automated_textmining>1))stop("automated_textmining must be in [0,1]",call.=FALSE)
if(any(edges$from==edges$to))stop("PPI self-loops are not supported",call.=FALSE)
nodes <- check_annotations(unique(c(edges$from,edges$to)),nodes,"gene")
nodes <- nodes[order(nodes$gene),,drop=FALSE]
fi<-match(edges$from,nodes$gene);ti<-match(edges$to,nodes$gene)
pair_key <- data.frame(low=pmin(fi,ti),high=pmax(fi,ti))
if(anyDuplicated(pair_key))stop("duplicate undirected edge",call.=FALSE)
layout_mode<-scalar_choice(params$layout %||% "kk","layout",c("kk","fr","circle"))
threshold<-scalar_number(params$label_degree_threshold %||% 5,"label_degree_threshold",integer=TRUE)
seed<-scalar_number(params$seed %||% 1,"seed",upper=.Machine$integer.max,integer=TRUE)
group_colours <- unlist(params$group_colours,use.names=TRUE)
if(is.null(group_colours) || anyDuplicated(names(group_colours)) || !setequal(unique(nodes$group),names(group_colours)))stop("group colours must exactly match node groups",call.=FALSE)
tryCatch(grDevices::col2rgb(group_colours),error=function(e)stop("invalid group colour",call.=FALSE))
# 2. 按完整 ID 建图；分组不依赖注释行位置，分数不作为布局距离
gr<-igraph::graph_from_data_frame(edges,directed=FALSE,vertices=data.frame(name=nodes$gene))
set.seed(seed)
pos<-switch(layout_mode,kk=igraph::layout_with_kk(gr,weights=NA),fr=igraph::layout_with_fr(gr,weights=NA),circle=igraph::layout_in_circle(gr))
nodes$x<-pos[,1];nodes$y<-pos[,2];nodes$degree<-as.numeric(igraph::degree(gr,mode="all"));nodes$labelled<-nodes$degree>threshold
edges$x<-nodes$x[match(edges$from,nodes$gene)];edges$y<-nodes$y[match(edges$from,nodes$gene)]
edges$xend<-nodes$x[match(edges$to,nodes$gene)];edges$yend<-nodes$y[match(edges$to,nodes$gene)]
dir.create("evidence",showWarnings=FALSE)
write.csv(edges,"evidence/plotted-edges.csv",row.names=FALSE)
write.csv(nodes,"evidence/node-layout.csv",row.names=FALSE)
# 3. 灰色加权边、分组圆点、节点度数和原例高连接度标签
p<-ggplot2::ggplot()+ggplot2::geom_segment(data=edges,ggplot2::aes(x=x,y=y,xend=xend,yend=yend,linewidth=automated_textmining),colour="grey60",alpha=.65)+ggplot2::scale_linewidth_continuous(range=c(.15,.9),limits=c(0,1),name="Text-mining score")+ggplot2::geom_point(data=nodes,ggplot2::aes(x=x,y=y,size=degree,fill=group),shape=21,colour="#333333",stroke=.4)+ggplot2::scale_size_continuous(range=c(2,8),name="Degree in shown graph")+ggplot2::scale_fill_manual(values=group_colours,name="Input group")+ggrepel::geom_text_repel(data=nodes[nodes$labelled,],ggplot2::aes(x=x,y=y,label=gene),size=3,max.overlaps=Inf,seed=seed,box.padding=.3,min.segment.length=0)+ggplot2::coord_equal(clip="off")+ggplot2::theme_void(base_size=params$font_size %||% 12,base_family=params$font_family %||% "sans")+ggplot2::theme(plot.margin=ggplot2::margin(20,25,20,25),plot.title=ggplot2::element_text(face="bold"),legend.position="right")+ggplot2::labs(title="Grouped protein interaction network",subtitle=paste(nrow(nodes),"nodes;",nrow(edges),"undirected edges; labels: degree >",threshold),caption="Line width: provided automated_textmining score; node size: degree in this displayed graph.")
save_gg(p)
