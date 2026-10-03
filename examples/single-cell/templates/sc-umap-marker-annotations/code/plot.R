source("code/common.R")
# 1. 检查标准坐标表与 marker 表
d <- validate_table(read.csv("data/input.csv", check.names=FALSE, fileEncoding="UTF-8"), c("cell_id","x","y","celltype"))
markers <- validate_table(read.csv("data/markers.csv", check.names=FALSE, fileEncoding="UTF-8"), c("celltype","marker"))
require_numeric(d,c("x","y"))
if(anyDuplicated(d$cell_id)) stop("cell_id must be unique")
if(anyNA(d$cell_id) || anyNA(d$celltype) || any(d$cell_id=="") || any(d$celltype=="")) stop("cell identifiers and celltype must be present")
if(diff(range(d$x))<=0 || diff(range(d$y))<=0) stop("both coordinate axes must have variation")
types <- sort(unique(d$celltype))
if(!all(types %in% markers$celltype)) stop("marker annotations missing for a celltype")
centres <- aggregate(cbind(x,y)~celltype,d,median)
centres$number <- match(centres$celltype,types)
centres$label <- vapply(centres$celltype,function(t) paste0(t," (",match(t,types),")\n",paste(head(unique(markers$marker[markers$celltype==t]),params$marker_limit %||% 5),collapse="\n")),character(1))
cols <- rep(c('#7F3C8D','#11A579','#3969AC','#E73F74','#80BA5A','#E68310','#008695','#CF1C90','#f97b72'),length.out=length(types)); names(cols)<-types
# 2. 保留参考的淡色点云、中心编号与外置文字；中心采用输入坐标中位数
mid <- mean(range(d$x)); span <- diff(range(d$x)); centers_left <- centres$x < mid
y_span <- diff(range(d$y)); label_range <- mean(range(d$y))+c(-0.72,0.72)*y_span
centres$label_x <- ifelse(centers_left,min(d$x)-span*0.26,max(d$x)+span*0.26)
centres$label_y <- centres$y
for(side in c(TRUE,FALSE)) {
 idx <- which(centers_left==side); idx <- idx[order(centres$y[idx])]
 centres$label_y[idx] <- if(length(idx)>1) seq(label_range[1],label_range[2],length.out=length(idx)) else mean(range(d$y))
}
p <- ggplot2::ggplot(d,ggplot2::aes(x,y,color=celltype))+
 ggplot2::geom_point(size=0.7,alpha=params$point_alpha %||% 0.3)+ggplot2::scale_color_manual(values=cols)+
 ggplot2::geom_point(data=centres,ggplot2::aes(x,y),inherit.aes=FALSE,size=6,shape=21,fill="white",color="black")+
 ggplot2::geom_text(data=centres,ggplot2::aes(x,y,label=number),inherit.aes=FALSE,size=3.2)+
 ggplot2::geom_segment(data=centres,ggplot2::aes(x=x,y=y,xend=label_x,yend=label_y),inherit.aes=FALSE,color="grey50",linewidth=0.35)+
 ggplot2::geom_label(data=centres,ggplot2::aes(x=label_x,y=label_y,label=label),inherit.aes=FALSE,size=3,fill="white",linewidth=0.3)+
 ggplot2::scale_x_continuous(limits=c(min(centres$label_x)-span*0.16,max(centres$label_x)+span*0.16))+
 ggplot2::scale_y_continuous(limits=c(min(d$y,centres$label_y)-y_span*0.18,max(d$y,centres$label_y)+y_span*0.18))+
 ggplot2::coord_equal(clip="off")+plot_theme()+
 ggplot2::theme(axis.text=ggplot2::element_blank(),axis.ticks=ggplot2::element_blank(),axis.line=ggplot2::element_blank(),legend.position="none",plot.margin=ggplot2::margin(15,25,15,25))+
 ggplot2::labs(x=NULL,y=NULL,caption=paste0(params$data_label %||% "Synthetic coordinates; tutorial marker labels"," · Cells shown: ",nrow(d)))
# 3. 显式输出
save_gg(p)
