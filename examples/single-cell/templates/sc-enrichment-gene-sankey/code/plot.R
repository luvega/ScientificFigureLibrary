# 绘图层：成员边与完整富集统计分别保留，不重新做富集或调控推断。
source('code/common.R')
library(ggplot2)
library(patchwork)
e <- validate_table(read.csv('data/memberships.csv',check.names=FALSE,fileEncoding='UTF-8'),c('gene','pathway','weight'))
r <- validate_table(read.csv('data/enrichment.csv',check.names=FALSE,fileEncoding='UTF-8'),c('pathway','gene_ratio','count','display_score'))
require_numeric(e,'weight');require_numeric(r,c('gene_ratio','count','display_score'))
if(any(e$weight<=0))stop('membership weights must be positive')
if(any(r$gene_ratio<0 | r$gene_ratio>1) || any(r$count<=0) || any(r$count!=floor(r$count)) || any(r$display_score<0))stop('invalid provided enrichment ranges')
if(anyNA(e[c('gene','pathway')]) || anyNA(r$pathway) || any(e$gene=='' | e$pathway=='') || any(r$pathway==''))stop('membership labels must be present')
if(anyDuplicated(e[c('gene','pathway')]) || anyDuplicated(r$pathway))stop('duplicate gene/pathway or enrichment keys')
if(!setequal(e$pathway,r$pathway))stop('membership and enrichment pathway identifiers must match')

layout_flows <- function(d,gap) {
  left_levels <- rev(unique(d$left)); right_levels <- rev(unique(d$right))
  if(!is.numeric(gap) || length(gap)!=1 || !is.finite(gap) || gap<0 || gap*(max(length(left_levels),length(right_levels))-1)>=1) stop('node_gap is too large for the provided nodes')
  available <- 1-gap*(max(length(left_levels),length(right_levels))-1)
  unit <- available/sum(d$weight)
  make_nodes <- function(ids,key,x) {
    height <- vapply(ids,function(id)sum(d$weight[d[[key]]==id])*unit,numeric(1))
    margin <- (1-sum(height)-gap*(length(ids)-1))/2
    bottom <- c(0,head(cumsum(height+gap),-1))+margin
    data.frame(id=ids,side=key,x=x,ymin=bottom,ymax=bottom+height,y=bottom+height/2)
  }
  left <- make_nodes(left_levels,'left',0);right <- make_nodes(right_levels,'right',1)
  lc <- setNames(left$ymin,left$id);rc <- setNames(right$ymin,right$id)
  polygons <- list();bounds <- list();t <- seq(0,1,length.out=50);blend <- 3*t^2-2*t^3
  for(i in seq_len(nrow(d))) {
    lo <- lc[d$left[i]];ro <- rc[d$right[i]];w <- d$weight[i]*unit
    lower <- (1-blend)*lo+blend*ro;upper <- (1-blend)*(lo+w)+blend*(ro+w)
    polygons[[i]] <- data.frame(x=c(t,rev(t)),y=c(lower,rev(upper)),flow_id=i,fill=d$fill[i])
    bounds[[i]] <- data.frame(left=d$left[i],right=d$right[i],left_min=lo,left_max=lo+w,right_min=ro,right_max=ro+w,width=w,weight=d$weight[i])
    lc[d$left[i]] <- lo+w;rc[d$right[i]] <- ro+w
  }
  list(polygons=do.call(rbind,polygons),bounds=do.call(rbind,bounds),nodes=rbind(left,right),unit=unit)
}

e$left<-e$gene;e$right<-e$pathway;e$fill<-'Provided membership';e$weight<-as.numeric(e$weight)
lay<-layout_flows(e,params$node_gap)
left_nodes<-lay$nodes[lay$nodes$side=='left',];right_nodes<-lay$nodes[lay$nodes$side=='right',]
path_col<-setNames(grDevices::hcl.colors(nrow(right_nodes),'Dark 3'),right_nodes$id)
node_fill<-ifelse(lay$nodes$side=='right',path_col[lay$nodes$id],'#D0D0D0')
right_nodes$label<-vapply(right_nodes$id,function(s)paste(strwrap(s,width=params$pathway_wrap),collapse='\n'),character(1))
p1 <- ggplot()+geom_polygon(data=lay$polygons,aes(x,y,group=flow_id),fill='#DDDDDD',colour='#B5B5B5',linewidth=0.22)+
 geom_rect(data=lay$nodes,aes(xmin=x-params$node_width/2,xmax=x+params$node_width/2,ymin=ymin,ymax=ymax),fill=node_fill,colour='grey45',linewidth=0.4)+
 geom_text(data=left_nodes,aes(x=-0.07,y=y,label=id),hjust=1,fontface='italic',size=params$font_size/3.5)+
 geom_text(data=right_nodes,aes(x=1.07,y=y,label=label),hjust=0,size=params$font_size/3.7)+
 coord_cartesian(xlim=c(-0.27,2.0),ylim=c(0,1),expand=FALSE,clip='off')+labs(title='Gene–pathway membership')+
 theme_void(base_size=params$font_size,base_family=params$font_family)+theme(plot.margin=margin(8,8,8,5))
bubble <- merge(r,right_nodes[c('id','y')],by.x='pathway',by.y='id',sort=FALSE)
p2 <- ggplot(bubble,aes(gene_ratio,y))+geom_point(aes(size=count,fill=display_score),shape=21,colour='grey20',stroke=0.45)+
 scale_fill_gradient(low='#78C2C4',high='#CB482E',name='Provided display score')+scale_size_area(max_size=params$max_bubble_size,name='Provided Count')+
 scale_x_continuous(expand=expansion(mult=c(0.07,0.22)))+scale_y_continuous(limits=c(0,1),expand=c(0,0))+labs(title='Provided enrichment',x='Provided gene ratio',y=NULL)+
 plot_theme()+theme(axis.text.y=element_blank(),axis.ticks.y=element_blank(),axis.line.y=element_blank(),plot.margin=margin(8,8,8,8))
p <- p1+p2+plot_layout(widths=c(3.8,1.5))+plot_annotation(title=params$title,caption='Teaching-example memberships and enrichment values; ribbon membership count differs from full enrichment Count',theme=theme(plot.title=element_text(size=params$font_size+2,face='bold'),plot.caption=element_text(size=params$font_size-2)))
save_gg(p)
writeLines(capture.output(sessionInfo()),'sessionInfo.txt')
cat('OK: source teaching-example tables rendered without enrichment testing\n')
