source("code/common.R", encoding="UTF-8")
raw <- matrix_from_table(read.csv("data/auc.csv",check.names=FALSE,fileEncoding="UTF-8"))
if(anyNA(rownames(raw)) || anyNA(colnames(raw)) || any(!nzchar(rownames(raw))) || any(!nzchar(colnames(raw))) || anyDuplicated(colnames(raw))) stop("matrix identifiers must be unique and nonempty")
if(any(raw<0 | raw>1)) stop("AUC values must be in [0,1]")
anno <- validate_table(read.csv("data/cells.csv",check.names=FALSE,fileEncoding="UTF-8"),c("cell_id","group","order"))
anno <- check_annotations(colnames(raw),anno,"cell_id"); require_numeric(anno,"order")
if(anyDuplicated(anno$order)) stop("cell order must be unique")
if(anyNA(anno$group)||any(!nzchar(anno$group))) stop("empty cell group")
anno <- anno[order(anno$order),]; raw <- raw[,anno$cell_id,drop=FALSE]
mode <- params$scale %||% "raw"
if(!mode %in% c("raw","row_zscore")) stop("scale must be raw or row_zscore")
m <- raw
if(mode=="row_zscore"){
  if(ncol(raw)<2) stop("row_zscore requires at least two cells")
  s <- apply(raw,1,stats::sd); m <- sweep(sweep(raw,1,rowMeans(raw),"-"),1,ifelse(s==0,1,s),"/")
}
write.csv(data.frame(regulon=rownames(m),m,check.names=FALSE),"evidence/plotted-values.csv",row.names=FALSE)
write.csv(anno,"evidence/plotted-cells.csv",row.names=FALSE)
bound <- max(abs(m)); if(bound==0)bound<-1
colfun <- if(mode=="raw") circlize::colorRamp2(c(0,0.5,1),c("#2166AC","#F7F7F7","#B2182B")) else circlize::colorRamp2(c(-bound,0,bound),c("#2166AC","#F7F7F7","#B2182B"))
gr <- unique(anno$group); colors <- setNames(grDevices::hcl.colors(length(gr),"Dark 3"),gr)
draw_pair(function(){
  ht <- ComplexHeatmap::Heatmap(m,name=if(mode=="raw") "Input AUC" else "Row z-score",col=colfun,
    cluster_rows=FALSE,cluster_columns=FALSE,show_column_names=isTRUE(params$show_cell_names),
    row_names_gp=grid::gpar(fontsize=10),column_names_gp=grid::gpar(fontsize=5),
    column_title="Tutorial subset · no cell-type annotation",
    top_annotation=ComplexHeatmap::HeatmapAnnotation(Group=anno$group,col=list(Group=colors)))
  ComplexHeatmap::draw(ht,heatmap_legend_side="right",annotation_legend_side="right")
})
