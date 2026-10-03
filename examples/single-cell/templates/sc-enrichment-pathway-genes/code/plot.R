# 1. 参数、已有结果和字体
source('code/common.R')
library(ggplot2)
x <- validate_table(read.csv('data/enrichment.csv', check.names=FALSE, fileEncoding='UTF-8'), c('group','pathway','qvalue','genes'))
require_numeric(x, 'qvalue')
if (any(x$qvalue < 0 | x$qvalue > 1)) stop('qvalue must lie in [0,1]')
if (anyNA(x[c('group','pathway','genes')]) || any(x$group == '' | x$pathway == '')) stop('group/pathway must be present')
# 2. 只进行展示变换；不富集、不重算统计
floor_p <- params$pvalue_floor %||% 1e-30
if (!is.numeric(floor_p) || floor_p <= 0 || floor_p > 1) stop('pvalue_floor must lie in (0,1]')
x$score <- -log10(pmax(x$qvalue, floor_p))
x$group <- factor(x$group, levels=unique(x$group))
x$position <- rev(seq_len(nrow(x))) * 1.75
n_genes <- params$max_genes %||% 5
x$gene_label <- vapply(strsplit(x$genes, '/', fixed=TRUE), function(v) paste(head(v,n_genes), collapse='/'), character(1))
palette <- c('#D51F26','#00A08A','#F2AD00','#F98400','#5BBCD6')
if (nlevels(x$group)>length(palette)) palette <- grDevices::hcl.colors(nlevels(x$group),'Dark 3')
palette <- setNames(palette[seq_len(nlevels(x$group))],levels(x$group))
# 3. 通路条形与基因文字，保留原布局的颜色绑定
p <- ggplot(x, aes(x=score,y=position,fill=group)) +
  geom_col(width=0.55,orientation='y',position='identity') +
  geom_text(aes(x=0.1,label=pathway),hjust=0,size=params$font_size/3.1) +
  geom_text(aes(x=0.1,y=position-0.62,label=gene_label,colour=group),hjust=0,fontface='italic',size=params$font_size/3.25) +
  facet_grid(group~.,scales='free_y',space='free_y',switch='y') +
  scale_fill_manual(values=palette) + scale_colour_manual(values=palette) +
  scale_x_continuous(expand=expansion(mult=c(0,0.35))) +
  scale_y_continuous(expand=expansion(add=c(0.95,0.6))) +
  labs(x='-log10(qvalue)',y=NULL,title=params$title,caption='Provided enrichment results; labels retain Entrez IDs') +
  plot_theme() + theme(axis.text.y=element_blank(),axis.ticks.y=element_blank(),legend.position='none',
    strip.background=element_rect(fill='grey95',colour=NA),strip.text.y.left=element_text(angle=0),
    plot.margin=margin(10,18,10,10),panel.spacing.y=grid::unit(0.1,'cm'))
# 4. 显式输出
save_gg(p)

# 5. 保存本次实际运行环境
writeLines(capture.output(sessionInfo()), "sessionInfo.txt")
cat("OK: preview.png and plot.pdf generated from declared inputs\n")
