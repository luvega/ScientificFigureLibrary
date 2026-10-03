source("code/common.R", encoding="UTF-8")
edges <- validate_table(read.csv("data/communication.csv",check.names=FALSE,fileEncoding="UTF-8"), c("group","source","target","ligand","receptor","interaction_id","value","pvalue"))
nodes <- validate_table(read.csv("data/nodes.csv",check.names=FALSE,fileEncoding="UTF-8"), c("celltype","colour","order"))
require_numeric(edges,c("value","pvalue")); require_numeric(nodes,"order")
if(any(edges$value<0) || any(edges$pvalue<0 | edges$pvalue>1)) stop("invalid value or pvalue")
if(anyNA(edges[c("group","source","target","ligand","receptor","interaction_id")]) || any(vapply(edges[c("group","source","target","ligand","receptor","interaction_id")],function(x)any(!nzchar(x)),logical(1)))) stop("empty edge identifiers")
if(anyDuplicated(edges[c("group","source","target","interaction_id")])) stop("duplicate interaction per cell pair")
nodes <- check_annotations(unique(c(edges$source,edges$target)),nodes,"celltype")
if(anyDuplicated(nodes$order)) stop("node order must be unique")
tryCatch(grDevices::col2rgb(nodes$colour),error=function(e)stop("invalid node colour"))
nodes <- nodes[order(nodes$order),]; groups <- unique(edges$group)
threshold <- params$pvalue_threshold %||% 0.05
if(!is.numeric(threshold)||length(threshold)!=1||!is.finite(threshold)||threshold<0||threshold>1) stop("invalid pvalue_threshold")
mode <- params$weight_mode %||% "significant_pairs"
if(!mode %in% c("significant_pairs","sum_value")) stop("invalid weight_mode")
filtered <- edges[edges$value>0 & edges$pvalue<threshold,]
if(!nrow(filtered)) stop("No edges remain after filters")
if(any(!groups %in% filtered$group)) stop("a group has no retained edges")
aggregated <- stats::aggregate(if(mode=="significant_pairs") rep(1,nrow(filtered)) else filtered$value,
  by=filtered[c("group","source","target")],FUN=sum)
names(aggregated)[4] <- "weight"
write.csv(aggregated,"evidence/aggregated-edges.csv",row.names=FALSE)
write.csv(filtered,"evidence/filtered-interactions.csv",row.names=FALSE)
draw_pair(function(){
  graphics::par(mfrow=c(1,length(groups)),mar=c(1,1,4,1),xpd=NA)
  for(g in groups){
    a <- aggregated[aggregated$group==g,]
    graph <- igraph::graph_from_data_frame(data.frame(from=a$source,to=a$target,weight=a$weight),directed=TRUE,vertices=data.frame(name=nodes$celltype))
    pos <- igraph::layout_in_circle(graph)
    igraph::plot.igraph(graph,layout=pos,vertex.color=nodes$colour,vertex.frame.color="#263546",vertex.size=18,
      vertex.label=NA,
      edge.color="#7C8D98A0",edge.width=0.6+a$weight/max(aggregated$weight)*(params$max_edge_width %||% 4),
      edge.arrow.size=0.5,edge.curved=0.2,rescale=FALSE,xlim=c(-1.6,1.6),ylim=c(-1.6,1.6),
      main=paste(g,if(mode=="significant_pairs") "Selected candidate count" else "Sum of input value"))
    graphics::text(pos[,1]*1.4,pos[,2]*1.5+ifelse(abs(pos[,2])<0.01,0.27,0),labels=nodes$celltype,cex=0.9,col="#263546",family="sans")
    graphics::legend("bottomleft",legend=c(paste("pvalue <",threshold),paste("max edge weight =",signif(max(aggregated$weight),4))),bty="n",cex=0.8)
  }
})
