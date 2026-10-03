# Lightweight averaging of provided numeric values along provided pseudotime.
# No trajectory, score, smoothing fit, significance or CI is calculated.
args<-commandArgs(trailingOnly=TRUE)
if(length(args)!=3)stop("usage: Rscript bin-precomputed-values.R points.csv output-directory bin-count")
bins<-suppressWarnings(as.numeric(args[3]));if(length(bins)!=1||!is.finite(bins)||bins!=floor(bins)||bins<2||bins>1000)stop("bin count must be an integer in [2,1000]")
bins<-as.integer(bins)
d<-read.csv(args[1],check.names=FALSE,stringsAsFactors=FALSE)
keys<-c("cell_id","feature","group","pseudotime","value")
if(!all(keys %in% names(d))||!nrow(d))stop("points missing required columns or rows")
if(anyDuplicated(d[c("cell_id","feature")])||anyNA(d[keys])||any(vapply(d[c("cell_id","feature","group")],function(v)any(!nzchar(trimws(as.character(v)))),logical(1))))stop("invalid point identifiers")
if(!is.numeric(d$pseudotime)||!is.numeric(d$value)||any(!is.finite(d$pseudotime))||any(!is.finite(d$value))||any(d$pseudotime<0)||max(d$pseudotime)==0)stop("invalid numeric values")
for(cell in unique(d$cell_id))if(length(unique(d$group[d$cell_id==cell]))!=1||length(unique(d$pseudotime[d$cell_id==cell]))!=1)stop("cell metadata must be consistent")
bin<-cut(d$pseudotime,seq(0,max(d$pseudotime),length.out=bins+1),include.lowest=TRUE,labels=FALSE)
result<-list()
for(feature in unique(d$feature))for(group in unique(d$group[d$feature==feature]))for(b in 1:bins){
 i<-which(d$feature==feature&d$group==group&bin==b);if(!length(i))next
 result[[length(result)+1]]<-data.frame(feature=feature,group=group,pseudotime=mean(d$pseudotime[i]),value=mean(d$value[i]),lower=NA_real_,upper=NA_real_,n_cells=length(i))
}
dir.create(args[2],recursive=TRUE,showWarnings=FALSE)
write.csv(do.call(rbind,result),file.path(args[2],"trends.csv"),row.names=FALSE,na="")
write.csv(d[keys],file.path(args[2],"points.csv"),row.names=FALSE)
