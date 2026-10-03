source("code/common.R", encoding="UTF-8")
x <- validate_table(read.csv("data/rss.csv",check.names=FALSE,fileEncoding="UTF-8"),c("celltype","regulon","rss"))
require_numeric(x,"rss")
if(any(x$rss<0 | x$rss>1)) stop("RSS values must be in [0,1]")
if(anyNA(x[c("celltype","regulon")]) || any(!nzchar(x$celltype)) || any(!nzchar(x$regulon))) stop("empty RSS identifiers")
if(anyDuplicated(x[c("celltype","regulon")])) stop("duplicate celltype/regulon")
groups <- unique(x$celltype)
universe <- x$regulon[x$celltype==groups[1]]
if(any(vapply(groups,function(g)!setequal(universe,x$regulon[x$celltype==g]),logical(1)))) stop("regulon universe mismatch")
top_n <- params$top_n %||% 4
if(!is.numeric(top_n)||length(top_n)!=1||!is.finite(top_n)||top_n<1||top_n!=as.integer(top_n)) stop("top_n must be a positive integer")
ranked <- do.call(rbind,lapply(groups,function(g){
  a<-x[x$celltype==g,]; a<-a[order(-a$rss,a$regulon,method="radix"),]; a$rank<-seq_len(nrow(a));a$highlight<-a$rank<=top_n;a
}))
ranked$celltype <- factor(ranked$celltype,levels=groups)
write.csv(ranked,"evidence/ranked-rss.csv",row.names=FALSE)
labels<-ranked[ranked$highlight,]
p<-ggplot2::ggplot(ranked,ggplot2::aes(rank,rss))+
  ggplot2::geom_point(colour="#1F77B4",alpha=0.45,size=2.5)+
  ggplot2::geom_point(data=labels,colour="#DC050C",size=2.8)+
  ggrepel::geom_text_repel(data=labels,ggplot2::aes(label=regulon),seed=20261002,size=3,max.overlaps=Inf,box.padding=0.35,min.segment.length=0)+
  ggplot2::facet_wrap(~celltype,ncol=params$facet_columns %||% 2)+
  ggplot2::scale_y_continuous(limits=c(0,1),expand=ggplot2::expansion(mult=c(0.03,0.08)))+
  ggplot2::labs(x="Regulon rank",y="Input RSS",title="Precomputed regulon specificity",subtitle="Synthetic example · rankings within each cell type")+
  plot_theme()+ggplot2::theme(panel.spacing=grid::unit(1.5,"lines"))
save_gg(p)
