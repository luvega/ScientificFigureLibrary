# 适配预计算 gseaResult；只重建绘图轨迹，保留原 NES/P值，不运行富集/置换。
args <- commandArgs(trailingOnly=TRUE)
if(!length(args) %in% c(3,4))stop('usage: Rscript adapters/gsea-result-to-tables.R result.RData output-directory running|rank [comma-separated-pathway-IDs]')
mode<-args[3];if(!mode %in% c('running','rank'))stop('mode must be running or rank')
env<-new.env(parent=baseenv());loaded<-load(args[1],envir=env)
objects<-lapply(loaded,function(n)get(n,envir=env));ok<-vapply(objects,function(x)all(c('geneList','geneSets','result','params') %in% names(attributes(x))),logical(1))
if(sum(ok)!=1)stop('RData must contain exactly one supplied gseaResult-like object')
a<-attributes(objects[[which(ok)]]);g<-a$geneList;r<-a$result;sets<-a$geneSets;exponent<-a$params$exponent
if(!is.numeric(g)||any(!is.finite(g))||is.null(names(g))||anyDuplicated(names(g))||any(diff(g)>0))stop('ranking must have unique named genes and descending finite statistics')
if(!is.numeric(exponent)||length(exponent)!=1||!is.finite(exponent)||exponent<0)stop('missing or invalid stored GSEA exponent')
if(!all(c('ID','Description','setSize','enrichmentScore','NES','p.adjust') %in% names(r)))stop('result lacks required stored fields')
selected<-if(length(args)==4)strsplit(args[4],',',fixed=TRUE)[[1]]else head(as.character(r$ID),if(mode=='running')2 else 10)
if(!length(selected)||anyDuplicated(selected)||!all(selected %in% r$ID))stop('selected pathway IDs must be unique and present in the supplied result')
r<-r[match(selected,r$ID),,drop=FALSE]
out<-args[2];dir.create(out,recursive=TRUE,showWarnings=FALSE)
ranked<-data.frame(gene_id=names(g),rank=seq_along(g),statistic=as.numeric(g))
summary<-data.frame(pathway_id=r$ID,description=r$Description,set_size=r$setSize,enrichment_score=r$enrichmentScore,nes=r$NES,p_adjust=r$p.adjust)
curves<-list();hits<-list();diagnostics<-list()
for(i in seq_len(nrow(r))){
 id<-as.character(r$ID[i]);present<-names(g) %in% sets[[id]];nh<-sum(present);nm<-length(g)-nh
 if(nh<1||nm<1||nh!=r$setSize[i])stop('stored setSize and supplied matched genes differ: ',id)
 weight<-abs(g)^exponent;denom<-sum(weight[present]);if(!is.finite(denom)||denom<=0)stop('invalid hit weight denominator')
 increments<-rep(-1/nm,length(g));increments[present]<-weight[present]/denom
 score<-cumsum(increments);extreme<-if(abs(max(score))>=abs(min(score)))max(score)else min(score)
 err<-abs(extreme-r$enrichmentScore[i]);if(err>1e-6)stop('reconstructed ES differs from stored ES: ',id,' error=',err)
 curves[[i]]<-data.frame(pathway_id=id,rank=seq_along(g),running_es=score)
 hits[[i]]<-data.frame(pathway_id=id,gene_id=names(g)[present],rank=which(present))
 diagnostics[[i]]<-data.frame(pathway_id=id,matched_set_size=nh,exponent=exponent,stored_es=r$enrichmentScore[i],reconstructed_es=extreme,absolute_error=err,terminal_es=tail(score,1))
}
write.csv(ranked,file.path(out,'ranking.csv'),row.names=FALSE,fileEncoding='UTF-8')
write.csv(summary,file.path(out,'enrichment.csv'),row.names=FALSE,fileEncoding='UTF-8')
write.csv(do.call(rbind,hits),file.path(out,'hits.csv'),row.names=FALSE,fileEncoding='UTF-8')
if(mode=='running')write.csv(do.call(rbind,curves),file.path(out,'curves.csv'),row.names=FALSE,fileEncoding='UTF-8')
dir.create(file.path(dirname(out),'evidence'),showWarnings=FALSE)
write.csv(do.call(rbind,diagnostics),file.path(dirname(out),'evidence/adapter-checks.csv'),row.names=FALSE,fileEncoding='UTF-8')
cat('Converted supplied result only: ',nrow(summary),' pathways, ',nrow(ranked),' ranks; exponent=',exponent,'\n',sep='')
