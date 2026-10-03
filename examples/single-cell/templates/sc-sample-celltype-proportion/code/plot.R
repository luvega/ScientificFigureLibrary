# 1. Read standard counts and explicit sample denominators.
library(ggplot2)
source("code/common.R",encoding="UTF-8")
d<-check_input_columns(read.csv("data/counts.csv",check.names=FALSE,stringsAsFactors=FALSE),c("sample_id","group","cell_type","count","total_cells"))
require_names(d,c("sample_id","group","cell_type"));require_unique(d,c("sample_id","cell_type"),"sample/cell type")
require_numeric(d,c("count","total_cells"))
if(any(d$count<0|d$count!=floor(d$count))||any(d$total_cells<=0|d$total_cells!=floor(d$total_cells)))stop("counts and denominators must be valid integers")
for(sample in unique(d$sample_id)){
 rows<-d[d$sample_id==sample,,drop=FALSE]
 if(length(unique(rows$group))!=1||length(unique(rows$total_cells))!=1)stop("sample group and denominator must be consistent")
 if(sum(rows$count)>rows$total_cells[1])stop("counts exceed sample denominator")
 if(isTRUE(params$complete_composition)&&sum(rows$count)!=rows$total_cells[1])stop("complete composition counts must equal denominator")
}
if(!is.logical(params$complete_composition)||length(params$complete_composition)!=1||is.na(params$complete_composition))stop("complete_composition must be boolean")
mode<-params$plot_mode
if(!mode %in% c("box_points","points"))stop("invalid plot_mode")
groups<-ordered_levels(d$group,params$group_order,"group");colors<-group_palette(groups,params$group_colors)
types<-ordered_levels(d$cell_type,params$cell_type_order,"cell type")
# 2. Compute percentages before any display filter; each library has equal weight.
d$percent<-100*d$count/d$total_cells
selected<-as.character(unlist(params$display_cell_types %||% types))
if(!length(selected)||anyDuplicated(selected)||any(!selected %in% types))stop("unknown or duplicated display cell types")
shown<-d[d$cell_type %in% selected,,drop=FALSE]
for(type in selected)if(!setequal(shown$sample_id[shown$cell_type==type],unique(d$sample_id)))stop("each displayed cell type requires explicit counts for every sample")
if(mode=="box_points"&&any(table(unique(d[c("sample_id","group")])$group)<2))stop("box_points requires at least two samples per group")
shown$group<-factor(shown$group,levels=groups);shown$cell_type<-factor(shown$cell_type,levels=types[types %in% selected])
sample_levels<-unique(d$sample_id)
shown$x<-as.integer(shown$group)+(match(shown$sample_id,sample_levels)-(length(sample_levels)+1)/2)*min(0.035,0.32/length(sample_levels))
comparisons<-check_input_columns(read.csv("data/comparisons.csv",check.names=FALSE,stringsAsFactors=FALSE),c("cell_type","group1","group2","y","label"),empty=TRUE)
if(nrow(comparisons)){
 require_names(comparisons,c("cell_type","group1","group2","label"));require_numeric(comparisons,"y")
 if(any(!comparisons$cell_type %in% types)||any(!comparisons$group1 %in% groups)||any(!comparisons$group2 %in% groups)||any(comparisons$group1==comparisons$group2))stop("comparison refers to unknown or identical groups")
 if(any(comparisons$y<0|comparisons$y>100))stop("comparison y must be a percentage")
 comparisons<-comparisons[comparisons$cell_type %in% selected,,drop=FALSE]
 comparisons$cell_type<-factor(comparisons$cell_type,levels=levels(shown$cell_type))
 comparisons$x1<-match(comparisons$group1,groups);comparisons$x2<-match(comparisons$group2,groups)
}
# 3. Preserve faceted box-and-point style; supplied annotations only.
p<-ggplot(shown,aes(y=percent))
if(mode=="box_points")p<-p+geom_boxplot(aes(x=as.integer(group),group=group,fill=group),width=0.5,alpha=0.22,outlier.shape=NA)
p<-p+geom_point(aes(x=x,color=group),size=2.8)+facet_wrap(~cell_type,ncol=params$facet_columns)+
 scale_color_manual(values=colors,drop=FALSE)+scale_fill_manual(values=colors,drop=FALSE)+
 scale_x_continuous(breaks=seq_along(groups),labels=groups,limits=c(0.5,length(groups)+0.5))+
 scale_y_continuous(limits=c(0,100),expand=expansion(mult=c(0.01,0.08)))+
 labs(title=params$title,x=NULL,y="Proportion of all sample cells (%)",color="Group",fill="Group")+
 theme_bw(base_size=params$font_size,base_family=params$font_family)+
 theme(panel.grid.minor=element_blank(),panel.grid.major.x=element_blank(),strip.background=element_blank(),strip.text=element_text(face="bold"),axis.text.x=element_text(angle=25,hjust=1),legend.position="bottom")
if(nrow(comparisons))p<-p+geom_segment(data=comparisons,aes(x=x1,xend=x2,y=y,yend=y),inherit.aes=FALSE)+geom_text(data=comparisons,aes(x=(x1+x2)/2,y=y,label=label),vjust=-0.5,inherit.aes=FALSE)
dir.create("evidence",showWarnings=FALSE)
write.csv(shown[,c("sample_id","group","cell_type","count","total_cells","percent")],"evidence/display-proportions.csv",row.names=FALSE)
save_gg(p)
