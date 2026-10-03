# 1. Read precomputed trend points and optional precomputed intervals.
library(ggplot2)
source("code/common.R",encoding="UTF-8")
d<-check_input_columns(read.csv("data/trends.csv",check.names=FALSE,stringsAsFactors=FALSE),c("feature","group","pseudotime","value","lower","upper","n_cells"))
require_names(d,c("feature","group"));require_numeric(d,c("pseudotime","value","n_cells"))
require_unique(d,c("feature","group","pseudotime"),"feature/group/pseudotime")
if(any(d$pseudotime<0)||any(d$n_cells<=0|d$n_cells!=floor(d$n_cells)))stop("invalid pseudotime or n_cells")
d$lower<-numeric_interval(d$lower,TRUE);d$upper<-numeric_interval(d$upper,TRUE)
if(any(xor(is.na(d$lower),is.na(d$upper))))stop("interval bounds must be supplied together")
interval<-!is.na(d$lower)
if(any(d$lower[interval]>d$value[interval]|d$value[interval]>d$upper[interval]))stop("interval must contain provided trend value")
if(!params$trend_kind %in% c("binned_mean","precomputed_fit"))stop("invalid trend_kind")
if(is.null(params$value_scale)||!nzchar(params$value_scale)||is.null(params$value_label)||!nzchar(params$value_label))stop("value scale and label are required")
groups<-ordered_levels(d$group,params$group_order,"group");colors<-group_palette(groups,params$group_colors)
features<-unique(d$feature)
for(feature in features)for(group in unique(d$group[d$feature==feature]))if(sum(d$feature==feature&d$group==group)<2)stop("each trend requires at least two coordinates")
# 2. Sort within keyed curves; do not fit, smooth, test or compute intervals.
d<-d[order(match(d$feature,features),match(d$group,groups),d$pseudotime),,drop=FALSE]
d$feature<-factor(d$feature,levels=features);d$group<-factor(d$group,levels=groups)
points<-check_input_columns(read.csv("data/points.csv",check.names=FALSE,stringsAsFactors=FALSE),c("cell_id","feature","group","pseudotime","value"),empty=TRUE)
if(nrow(points)){
 require_names(points,c("cell_id","feature","group"));require_numeric(points,c("pseudotime","value"));require_unique(points,c("cell_id","feature"),"cell/feature")
 if(any(!points$feature %in% features)||any(!points$group %in% groups)||any(points$pseudotime<0))stop("points contain unknown feature/group or invalid pseudotime")
 for(cell in unique(points$cell_id))if(length(unique(points$group[points$cell_id==cell]))!=1||length(unique(points$pseudotime[points$cell_id==cell]))!=1)stop("cell group and pseudotime must be consistent")
 points$feature<-factor(points$feature,levels=features);points$group<-factor(points$group,levels=groups)
}
# 3. Draw only supplied values; mean and fitted curves have distinct captions.
p<-ggplot(d,aes(pseudotime,value,color=group,group=group))
if(any(interval))p<-p+geom_ribbon(data=d[!is.na(d$lower),,drop=FALSE],aes(ymin=lower,ymax=upper,fill=group),alpha=0.15,color=NA)
if(isTRUE(params$show_points)&&nrow(points))p<-p+geom_point(data=points,alpha=0.15,size=0.7)
p<-p+geom_line(linewidth=0.85)+facet_wrap(~feature,scales="free_y",ncol=params$facet_columns)+
 scale_color_manual(values=colors)+
 labs(title=params$title,subtitle=paste0(if(params$trend_kind=="binned_mean")"Binned mean" else "Provided fitted values",if(any(interval))"; provided intervals" else "; no interval supplied"),x="Stored pseudotime",y=params$value_label,color=NULL,fill=NULL)+
 plot_theme()+theme(strip.text=element_text(face="bold"),legend.position="bottom")
if(any(interval))p<-p+scale_fill_manual(values=colors)
dir.create("evidence",showWarnings=FALSE)
write.csv(d,"evidence/display-trends.csv",row.names=FALSE,na="")
save_gg(p)
