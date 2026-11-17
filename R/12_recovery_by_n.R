# archivo: R/12_recovery_by_n.R
# Grilla fijada antes de correrla: cuántos comercios hacen falta para
# recuperar E[lambda] y E[mu]. No cambia el panel de 2,000 con semilla 42.
# n = 500, 1000, 2000, 3000, 5000. Semillas 1 a 10.
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
NS <- c(500L, 1000L, 2000L, 3000L, 5000L)
SEEDS <- 1:10

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
  base <- data.table(
    n = n, seed = seed,
    param = c("E[lambda]=r/alpha", "E[mu]=s/beta")
  )
  if (is.null(fit)) {
    base[, `:=`(truth = c(TRUTH$r / TRUTH$alpha, TRUTH$s / TRUTH$beta),
                estimate = NA_real_, rel_error = NA_real_)]
    return(base)
  }
  cf <- coef(fit)
  est <- c(cf[["r"]] / cf[["alpha"]], cf[["s"]] / cf[["beta"]])
  tru <- c(TRUTH$r / TRUTH$alpha, TRUTH$s / TRUTH$beta)
  base[, `:=`(truth = tru, estimate = est, rel_error = (est - tru) / tru)]
  base
}

rows <- rbindlist(lapply(NS, function(n) {
  cat("n =", n, "\n")
  rbindlist(lapply(SEEDS, function(seed) one(n, seed)))
}))

summary_dt <- summarize_recovery(rows)
print(summary_dt)

fwrite(rows, "outputs/tables/12_recovery_by_n_detail.csv")
fwrite(summary_dt, "outputs/tables/12_recovery_by_n_summary.csv")

labels <- c("E[lambda]=r/alpha" = "E[lambda]", "E[mu]=s/beta" = "E[mu]")
plot_dt <- copy(summary_dt)
plot_dt[, param_lab := labels[param]]
p <- ggplot(plot_dt, aes(n, 100 * median_abs_rel_error, color = param_lab)) +
  geom_line() +
  geom_point() +
  labs(x = "Comercios", y = "Mediana del error absoluto (%)", color = NULL,
       title = "Recuperación de las medias, 10 semillas") +
  theme_bw()
ggsave("outputs/figures/12_recovery_by_n.png", p, width = 8, height = 4.5, dpi = 150)
cat("12 OK\n")
