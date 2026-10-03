# 1. 类别按字符读取，保留完整行列名
source('code/common.R')
library(ComplexHeatmap)
a<-read.csv('data/category_matrix.csv',check.names=FALSE,fileEncoding='UTF-8',colClasses='character')
require_columns(a,'row_id','category_matrix')
if(ncol(a)<2||names(a)[1]!='row_id')stop('category_matrix requires row_id first and at least one category column')
if(any(is.na(a$row_id)|trimws(a$row_id)=='')||anyDuplicated(a$row_id))stop('row_id must be nonempty and unique')
column_ids<-names(a)[-1]
if(anyDuplicated(column_ids)||any(is.na(column_ids)|trimws(column_ids)==''))stop('matrix column identifiers must be nonempty and unique')
m<-as.matrix(a[-1]);rownames(m)<-a$row_id
if(any(is.na(m)|trimws(m)==''))stop('matrix categories must be nonempty')
ca<-read.csv('data/column_annotations.csv',check.names=FALSE,fileEncoding='UTF-8',colClasses='character')
require_columns(ca,c('column_id','group','color'),'column_annotations')
ca<-check_annotations(column_ids,ca,'column_id')
if(any(is.na(ca$group)|trimws(ca$group)==''))stop('annotation groups must be nonempty')
if(any(is.na(ca$color)|!grepl('^#[0-9A-Fa-f]{6}$',ca$color)))stop('annotation colors must be six-digit hexadecimal colors')
if(any(vapply(split(ca$color,ca$group),function(z)length(unique(toupper(z)))!=1,logical(1))))stop('each annotation group must have one consistent color')
cc<-read.csv('data/category_colors.csv',check.names=FALSE,fileEncoding='UTF-8',colClasses='character')
require_columns(cc,c('category','color'),'category_colors')
if(any(is.na(cc$category)|trimws(cc$category)=='')||anyDuplicated(cc$category)||!setequal(cc$category,as.vector(m)))stop('category color keys must be unique and exactly match observed categories')
if(any(is.na(cc$color)|!grepl('^#[0-9A-Fa-f]{6}$',cc$color)))stop('category colors must be six-digit hexadecimal colors')
# 2. 注释按键对齐；无连续尺度、聚类或重排
group_colors<-setNames(ca$color[!duplicated(ca$group)],ca$group[!duplicated(ca$group)])
top<-HeatmapAnnotation(Group=ca$group,col=list(Group=group_colors),border=TRUE,show_annotation_name=FALSE,simple_anno_size=grid::unit(4,'mm'))
h<-Heatmap(m,name=params$legend_title %||% 'Category',col=setNames(cc$color,cc$category),cluster_rows=FALSE,cluster_columns=FALSE,
 show_row_names=TRUE,show_column_names=TRUE,row_names_side='left',column_names_rot=45,top_annotation=top,
 column_title=params$title %||% 'Categorical matrix',border='black',rect_gp=grid::gpar(col='grey65',lwd=.7),
 row_names_gp=grid::gpar(fontsize=params$font_size,fontfamily=params$font_family),column_names_gp=grid::gpar(fontsize=params$font_size,fontfamily=params$font_family),
 column_title_gp=grid::gpar(fontsize=params$font_size+2,fontfamily=params$font_family))
# 3. 输出显示数据和实际 PNG/PDF
write.csv(data.frame(row_id=rownames(m),m,check.names=FALSE),'evidence/display_matrix.csv',row.names=FALSE)
write.csv(ca,'evidence/aligned_column_annotations.csv',row.names=FALSE)
write.csv(cc,'evidence/display_category_colors.csv',row.names=FALSE)
draw_pair(function()ComplexHeatmap::draw(h,heatmap_legend_side='right',annotation_legend_side='right',padding=grid::unit(c(5,5,5,5),'mm')))
