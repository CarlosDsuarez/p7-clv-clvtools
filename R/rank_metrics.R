# Orden y concentración del pronóstico. Los usan R/16_holdout_rank.R y los tests.
safe_spearman <- function(pred, actual) {
  if (length(unique(pred)) < 2 || length(unique(actual)) < 2) return(NA_real_)
  suppressWarnings(cor(pred, actual, method = "spearman"))
}

top_decile_capture <- function(pred, actual) {
  total <- sum(actual)
  if (!is.finite(total) || total <= 0) return(NA_real_)
  k <- ceiling(length(pred) * 0.10)
  chosen <- order(pred, decreasing = TRUE)[seq_len(k)]
  sum(actual[chosen]) / total
}
