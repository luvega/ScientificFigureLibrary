source("code/common.R")
# 1. 输入为已分析的通讯边表，名称按列保存
d <- validate_table(read.csv("data/input.csv",check.names=FALSE,fileEncoding="UTF-8"),c("source","target","ligand","receptor","value","pvalue"))
require_numeric(d,c("value","pvalue"))
if(any(d$value < 0) || any(d$pvalue < 0 | d$pvalue > 1)) stop("invalid weight or pvalue")
d <- d[d$value>0 & d$pvalue < (params$pvalue_threshold %||% 0.05),]
if(!nrow(d)) stop("No edges remain after filters")
node_table <- unique(rbind(data.frame(celltype=d$source,gene=d$ligand),data.frame(celltype=d$target,gene=d$receptor)))
node_table <- node_table[order(node_table$celltype,node_table$gene),]
node_table$id <- paste0("node",seq_len(nrow(node_table)))
lookup <- function(cell,gene) vapply(seq_along(cell),function(i) node_table$id[which(node_table$celltype==cell[i] & node_table$gene==gene[i])],character(1))
links <- data.frame(from=lookup(d$source,d$ligand),to=lookup(d$target,d$receptor),value=d$value)
groups <- setNames(node_table$celltype,node_table$id)
types <- sort(unique(node_table$celltype)); palette <- rep(c('#83A67B','#476F78','#D59A1A','#4489A6','#AF3F22','#8F6786','#CDB497'),length.out=length(types))
colors <- setNames(palette,types); grid_cols <- setNames(colors[node_table$celltype],node_table$id)
# 2. 分组扇区、明确方向与权重
draw <- function(){
 circlize::circos.clear(); on.exit(circlize::circos.clear(),add=TRUE)
 circlize::circos.par(start.degree=90,canvas.xlim=c(-1.3,1.3),canvas.ylim=c(-1.3,1.3),points.overflow.warning=FALSE)
 circlize::chordDiagram(links,order=node_table$id,grid.col=grid_cols,group=groups,
   transparency=params$transparency %||% 0.65,directional=1,direction.type=c("arrows","diffHeight"),
   link.arr.type="triangle",link.border="white",link.sort=TRUE,link.largest.ontop=TRUE,
   big.gap=12,small.gap=3,annotationTrack="grid",preAllocateTracks=list(list(track.height=0.11),list(track.height=0.19)))
 circlize::circos.trackPlotRegion(track.index=2,bg.border=NA,panel.fun=function(x,y){
   id<-circlize::get.cell.meta.data("sector.index"); lim<-circlize::get.cell.meta.data("xlim")
   circlize::circos.text(mean(lim),0.25,node_table$gene[match(id,node_table$id)],facing="clockwise",niceFacing=TRUE,adj=c(0,0.5),cex=params$label_cex %||% 0.65)
 })
 for(t in types) circlize::highlight.sector(node_table$id[node_table$celltype==t],track.index=1,col=grDevices::adjustcolor(colors[t],alpha.f=0.65),border=NA,text=t,text.col="black",cex=0.95,niceFacing=TRUE,text.vjust="1.9mm")
}
# 3. 生成PNG与PDF
draw_pair(draw)
