source("code/common.R", encoding="UTF-8")
cells<-validate_table(read.csv("data/cells.csv",check.names=FALSE,fileEncoding="UTF-8"),c("cell_id","x","y","celltype","pseudotime"))
curves<-validate_table(read.csv("data/curves.csv",check.names=FALSE,fileEncoding="UTF-8"),c("lineage","order","x","y"))
require_numeric(cells,c("x","y","pseudotime")); require_numeric(curves,c("order","x","y"))
if(anyNA(cells[c("cell_id","celltype")])||any(!nzchar(cells$cell_id))||any(!nzchar(cells$celltype))) stop("empty cell identifiers")
if(anyDuplicated(cells$cell_id)) stop("cell_id must be unique")
if(any(cells$pseudotime<0)) stop("pseudotime must be nonnegative")
if(anyNA(curves$lineage)||any(!nzchar(curves$lineage))) stop("empty lineage")
if(any(curves$order<1|curves$order!=as.integer(curves$order))) stop("curve order must be positive integers")
if(anyDuplicated(curves[c("lineage","order")])) stop("duplicate curve order")
if(any(table(curves$lineage)<2)) stop("each lineage requires at least two curve points")
curves<-curves[order(curves$lineage,curves$order),]
cells$celltype<-factor(cells$celltype,levels=unique(cells$celltype))
write.csv(curves,"evidence/plotted-curves.csv",row.names=FALSE)
write.csv(cells,"evidence/plotted-cells.csv",row.names=FALSE)
base<-ggplot2::ggplot(cells,ggplot2::aes(x,y))+
  ggplot2::coord_equal()+plot_theme()+ggplot2::labs(x="Embedding 1",y="Embedding 2")
p1<-base+ggplot2::geom_point(ggplot2::aes(colour=celltype),size=params$point_size %||% 0.7,alpha=0.65)+
  ggplot2::geom_path(data=curves,ggplot2::aes(x,y,group=lineage),inherit.aes=FALSE,colour="black",linewidth=params$curve_width %||% 0.8)+
  ggplot2::scale_colour_manual(values=setNames(grDevices::hcl.colors(nlevels(cells$celltype),"Dark 3"),levels(cells$celltype)))+
  ggplot2::labs(colour="Cell type",title="Cell types and input curves")
p2<-base+ggplot2::geom_point(ggplot2::aes(colour=pseudotime),size=params$point_size %||% 0.7,alpha=0.75)+
  ggplot2::geom_path(data=curves,ggplot2::aes(x,y,group=lineage),inherit.aes=FALSE,colour="black",linewidth=params$curve_width %||% 0.8)+
  ggplot2::scale_colour_gradientn(colours=grDevices::hcl.colors(20,"Viridis"))+
  ggplot2::labs(colour="Input pseudotime",title="Pseudotime and input curves")
save_gg(patchwork::wrap_plots(p1,p2,ncol=2)+patchwork::plot_annotation(title="Precomputed trajectory overlay",subtitle="Synthetic coordinates and curves · no trajectory inference"))
