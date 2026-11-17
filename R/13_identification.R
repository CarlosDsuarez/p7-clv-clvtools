# archivo: R/13_identification.R
# Grilla fijada antes de correrla. Extiende la de R/12 con n = 10000 y 20000
# y guarda s y beta para ver si se mueven juntos.
# Semillas 1 a 10. No incluye la semilla 42.
source("R/00_utils.R")
source("R/simulate.R")
source("R/recovery_grid.R")
suppressPackageStartupMessages({
  library(CLVTools)
  library(data.table)
  library(ggplot2)
})
ensure_dirs()

TRUTH <- list(r = 0.553, alpha = 10.578, s = 0.606, beta = 11.669)
NS <- c(500L, 1000L, 2000L, 3000L, 5000L, 10000L, 20000L)
SEEDS <- 1:10
PARAMS <- c("r", "alpha", "s", "beta", "E[lambda]=r/alpha", "E[mu]=s/beta")

truth_of <- function() {
  c(TRUTH$r, TRUTH$alpha, TRUTH$s, TRUTH$beta,
    TRUTH$r / TRUTH$alpha, TRUTH$s / TRUTH$beta)
}

one <- function(n, seed) {
  tx <- simulate_pnbd(
    n = n, r = TRUTH$r, alpha = TRUTH$alpha, s = TRUTH$s, beta = TRUTH$beta,
    t_end = 78, first_max = 12, seed = seed
  )
  tx[, Date := format(as.Date(Date), "%Y-%m-%d")]
  clv <- clvdata(tx, date.format = "ymd", time.unit = TIME_UNIT,
                 estimation.split = EST_SPLIT_WEEKS,
                 name.id = "Id", name.date = "Date", name.price = "Price")
  fit <- tryCatch(pnbd(clv, verbose = FALSE), error = function(e) NULL)
  tru <- truth_of()
  base <- data.table(n = n, seed = seed, param = PARAMS, truth = tru)
  cf <- if (is.null(fit)) rep(NA_real_, 4) else coef(fit)[c("r", "alpha", "s", "beta")]
  if (anyNA(cf)) {
    base[, `:=`(estimate = NA_real_, rel_error = NA_real_)]
    return(base)
  }
  est <- c(cf[["r"]], cf[["alpha"]], cf[["s"]], cf[["beta"]],
           cf[["r"]] / cf[["alpha"]], cf[["s"]] / cf[["beta"]])
  base[, `:=`(estimate = est, rel_error = (est - tru) / tru)]
  base
}

rows <- rbindlist(lapply(NS, function(n) {
  cat("n =", n, "\n")
  rbindlist(lapply(SEEDS, function(seed) one(n, seed)))
}))

summary_dt <- summarize_recovery(rows)
cors <- cor_s_beta(rows)
print(summary_dt[param %in% c("E[lambda]=r/alpha", "E[mu]=s/beta", "s", "beta")])
print(cors)

old <- fread("outputs/tables/12_recovery_by_n_summary.csv")
chk <- merge(
  old,
  summary_dt[param %in% c("E[lambda]=r/alpha", "E[mu]=s/beta")],
  by = c("n", "param"),
  suffixes = c("_old", "_new")
)
gap <- max(abs(chk$median_abs_rel_error_old - chk$median_abs_rel_error_new))
cat("max gap vs grilla 12:", gap, "\n")
stopifnot("la grilla 1-5000 no reproduce el archivo 12" = gap < 1e-8)

fwrite(rows, "outputs/tables/13_recovery_detail.csv")
fwrite(summary_dt, "outputs/tables/13_recovery_summary.csv")
fwrite(cors, "outputs/tables/13_param_correlation.csv")

labels <- c("E[lambda]=r/alpha" = "E[lambda]", "E[mu]=s/beta" = "E[mu]")
plot_dt <- summary_dt[param %in% names(labels)]
plot_dt[, param_lab := labels[param]]
p <- ggplot(plot_dt, aes(n, 100 * median_abs_rel_error, color = param_lab)) +
  geom_line() +
  geom_point() +
  labs(x = "Comercios", y = "Mediana del error absoluto (%)", color = NULL,
       title = "Recuperación hasta 20,000 comercios, 10 semillas") +
  theme_bw()
ggsave("outputs/figures/13_recovery_by_n.png", p, width = 8, height = 4.5, dpi = 150)
cat("13 OK\n")
