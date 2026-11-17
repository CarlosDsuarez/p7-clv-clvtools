# Resume el error relativo de una grilla de recuperaciones.
# detail: n, seed, param, rel_error
suppressPackageStartupMessages(library(data.table))

summarize_recovery <- function(detail) {
  stopifnot(all(c("n", "param", "rel_error") %in% names(detail)))
  detail[!is.na(rel_error), .(
    n_ok = .N,
    mean_rel_error = mean(rel_error),
    sd_rel_error = sd(rel_error),
    median_abs_rel_error = median(abs(rel_error))
  ), by = .(n, param)][order(param, n)]
}
