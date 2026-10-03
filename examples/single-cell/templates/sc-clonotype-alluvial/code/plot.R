# 绘图层：输入是已确定的celltype与clone-size分组交叉计数。
source('code/common.R')
library(ggplot2)
d <- validate_table(read.csv('data/flows.csv',check.names=FALSE,fileEncoding='UTF-8'),c('sample','celltype','clone_class','count'))
require_numeric(d,'count')
if(any(d$count<=0) || any(d$count!=floor(d$count)))stop('flow counts must be positive integers')
if(anyNA(d[c('sample','celltype','clone_class')]) || any(vapply(d[c('sample','celltype','clone_class')],function(v)any(v==''),logical(1))))stop('flow annotation labels must be present')
if(anyDuplicated(d[c('sample','celltype','clone_class')]))stop('duplicate sample/celltype/clone_class keys')

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

celltypes <- unique(d$celltype);palette <- setNames(c('#F3B9A8','#D4C977','#A0D887','#8FD4CC',grDevices::hcl.colors(length(celltypes),'Dark 3'))[seq_along(celltypes)],celltypes)
layouts <- list();polygons <- list();nodes <- list();bounds <- list()
for(sample in unique(d$sample)) {
 s <- d[d$sample==sample,,drop=FALSE];s$left<-s$celltype;s$right<-s$clone_class;s$weight<-s$count;s$fill<-s$celltype
 lay <- layout_flows(s,params$node_gap);layouts[[sample]]<-lay
 q<-lay$polygons;q$sample<-sample;q$flow_id<-paste(sample,q$flow_id,sep=':');polygons[[sample]]<-q
 n<-lay$nodes;n$sample<-sample;n$fill<-ifelse(n$side=='left',palette[n$id],'#FFFFFF');nodes[[sample]]<-n
 b<-lay$bounds;b$sample<-sample;bounds[[sample]]<-b
}
all_polygons<-do.call(rbind,polygons);all_nodes<-do.call(rbind,nodes);all_bounds<-do.call(rbind,bounds)
p <- ggplot()+geom_polygon(data=all_polygons,aes(x,y,group=flow_id,fill=fill),alpha=0.6,colour=NA)+
 geom_rect(data=all_nodes,aes(xmin=x-params$node_width/2,xmax=x+params$node_width/2,ymin=ymin,ymax=ymax),fill=all_nodes$fill,colour='grey35',linewidth=0.5)+
 geom_text(data=all_nodes,aes(x=x,y=y,label=id),size=params$font_size/3.5)+facet_wrap(~sample,nrow=1)+
 scale_fill_manual(values=palette,name='Provided celltype')+coord_cartesian(xlim=c(-0.18,1.18),ylim=c(-0.03,1.06),clip='off')+
 labs(title=params$title,caption='Synthetic annotation counts; ribbon widths are normalized within sample; no inferred migration or clonal transition')+
 theme_void(base_size=params$font_size,base_family=params$font_family)+theme(strip.text=element_text(face='bold'),legend.position='bottom',plot.margin=margin(15,12,15,12))
save_gg(p)
writeLines(capture.output(sessionInfo()),'sessionInfo.txt')
cat('OK: supplied annotation counts rendered without defining clonotypes\n')
