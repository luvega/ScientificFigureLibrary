# Input: cell_id/sample_id/group/cell_type CSV. Counts only; no QC or group inference.
args<-commandArgs(trailingOnly=TRUE)
if(length(args)!=2)stop("usage: Rscript counts-from-metadata.R metadata.csv output-directory")
d<-read.csv(args[1],check.names=FALSE,stringsAsFactors=FALSE)
keys<-c("cell_id","sample_id","group","cell_type")
if(!all(keys %in% names(d))||!nrow(d))stop("metadata missing required columns or rows")
if(anyDuplicated(d$cell_id)||anyNA(d[keys])||any(vapply(d[keys],function(v)any(!nzchar(trimws(as.character(v)))),logical(1))))stop("metadata has duplicate or empty identifiers")
for(sample in unique(d$sample_id))if(length(unique(d$group[d$sample_id==sample]))!=1)stop("sample group must be unique")
samples<-unique(d$sample_id);types<-unique(d$cell_type)
tab<-table(factor(d$sample_id,levels=samples),factor(d$cell_type,levels=types))
out<-expand.grid(sample_id=samples,cell_type=types,stringsAsFactors=FALSE)
out$count<-as.vector(tab);out$total_cells<-rowSums(tab)[match(out$sample_id,samples)]
out$group<-d$group[match(out$sample_id,d$sample_id)]
dir.create(args[2],recursive=TRUE,showWarnings=FALSE)
write.csv(out[,c("sample_id","group","cell_type","count","total_cells")],file.path(args[2],"counts.csv"),row.names=FALSE)
writeLines("cell_type,group1,group2,y,label",file.path(args[2],"comparisons.csv"))
