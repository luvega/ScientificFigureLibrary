# Only standardizes an already exported result table and supplied coordinates.
# Group-level edges cannot be assigned to several individual spots of the same type.
args<-commandArgs(trailingOnly=TRUE)
if(length(args)!=4)stop("usage: Rscript edges-from-cellchat-table.R result.csv nodes.csv colors.csv output-directory")
d<-read.csv(args[1],check.names=FALSE,stringsAsFactors=FALSE)
n<-read.csv(args[2],check.names=FALSE,stringsAsFactors=FALSE)
cmap<-read.csv(args[3],check.names=FALSE,stringsAsFactors=FALSE)
if(!all(c("source","target","interaction_name","ligand","receptor","prob") %in% names(d))||!all(c("node_id","sample_id","cell_type","x","y") %in% names(n)))stop("missing result or coordinate columns")
if(anyDuplicated(n$node_id)||length(unique(n$sample_id))!=1)stop("node identifiers or sample invalid")
map_ids<-function(values){
 if(all(values %in% n$node_id))return(values)
 if(anyDuplicated(n$cell_type)||!all(values %in% n$cell_type))stop("unknown or ambiguous group endpoints")
 n$node_id[match(values,n$cell_type)]
}
out<-data.frame(edge_id=paste0("edge-",seq_len(nrow(d))),source=map_ids(d$source),target=map_ids(d$target),signal=d$interaction_name,ligand=d$ligand,receptor=d$receptor,weight=d$prob)
if(anyDuplicated(out[c("signal","source","target")]))stop("duplicate signal endpoints require an explicit upstream aggregation choice")
if(!is.numeric(out$weight)||any(!is.finite(out$weight))||any(out$weight<0))stop("invalid probability/score")
dir.create(args[4],recursive=TRUE,showWarnings=FALSE)
write.csv(out,file.path(args[4],"edges.csv"),row.names=FALSE);write.csv(n,file.path(args[4],"nodes.csv"),row.names=FALSE)
write.csv(cmap,file.path(args[4],"celltype_colors.csv"),row.names=FALSE)
