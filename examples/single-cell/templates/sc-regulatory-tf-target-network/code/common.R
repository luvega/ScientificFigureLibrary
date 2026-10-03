# 1. 读取已声明的参数和输入；不安装包、不执行上游分析
options(stringsAsFactors = FALSE)
params <- yaml::read_yaml("params.yml")
if (is.null(params)) params <- list()
`%||%` <- function(x, y) if (is.null(x)) y else x
require_columns <- function(x, columns, label = "input") {
  missing <- setdiff(columns, names(x))
  if (length(missing)) stop(label, " missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!nrow(x)) stop(label, " has no rows", call. = FALSE)
  invisible(x)
}
validate_table <- function(x, columns = character(), label = "input") {
  require_columns(x, columns, label)
  x
}
require_numeric <- function(x, columns, finite = TRUE) {
  for (name in columns) {
    if (!is.numeric(x[[name]])) stop(name, " must be numeric", call. = FALSE)
    if (finite && any(!is.finite(x[[name]]))) stop(name, " contains missing or non-finite values", call. = FALSE)
  }
  invisible(x)
}
matrix_from_table <- function(x) {
  require_columns(x, character())
  if (ncol(x) < 2 || anyDuplicated(x[[1]])) stop("matrix requires unique row identifiers and numeric columns", call. = FALSE)
  m <- as.matrix(x[-1]); rownames(m) <- x[[1]]
  if (!is.numeric(m) || any(!is.finite(m))) stop("matrix must contain finite numeric values", call. = FALSE)
  m
}
check_annotations <- function(ids, annotation, key) {
  require_columns(annotation, key)
  if (anyDuplicated(annotation[[key]]) || !setequal(ids, annotation[[key]])) stop("annotation identifiers do not match matrix identifiers", call. = FALSE)
  annotation[match(ids, annotation[[key]]), , drop = FALSE]
}
plot_theme <- function() ggplot2::theme_classic(base_size = params$font_size %||% 12, base_family = params$font_family %||% "sans")
save_gg <- function(p) {
  ggplot2::ggsave("preview.png", plot = p, device = ragg::agg_png, width = params$width %||% 9,
    height = params$height %||% 6, units = "in", dpi = params$dpi %||% 300, bg = "white")
  ggplot2::ggsave("plot.pdf", plot = p, device = grDevices::cairo_pdf, width = params$width %||% 9,
    height = params$height %||% 6, units = "in", bg = "white")
}
draw_pair <- function(draw) {
  w <- params$width %||% 9; h <- params$height %||% 6
  ragg::agg_png("preview.png", width = w, height = h, units = "in", res = params$dpi %||% 300, background = "white")
  tryCatch(draw(), finally = grDevices::dev.off())
  grDevices::cairo_pdf("plot.pdf", width = w, height = h, family = params$font_family %||% "sans", bg = "white")
  tryCatch(draw(), finally = grDevices::dev.off())
}

# 2. 名称按完整字符串匹配，边与节点不靠行序关联
require_ids <- function(x, columns, label) {
  for (nm in columns) if (!is.character(x[[nm]]) || anyNA(x[[nm]]) || any(!nzchar(trimws(x[[nm]])))) stop(label, " contains empty identifiers", call.=FALSE)
}
scalar_number <- function(x, name, lower=0, upper=Inf, integer=FALSE) {
  if (!is.numeric(x) || length(x)!=1 || !is.finite(x) || x<lower || x>upper || (integer && x!=floor(x))) stop("invalid ", name, call.=FALSE)
  x
}
scalar_choice <- function(x, name, choices) {
  if (!is.character(x) || length(x)!=1 || !x %in% choices) stop("invalid ", name, call.=FALSE)
  x
}
for (nm in c("width","height","dpi","font_size")) if (!is.null(params[[nm]])) scalar_number(params[[nm]],nm,lower=1)
