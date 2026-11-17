# archivo: R/11_bnpl_merchants.R
# Puente a comercios BNPL. No hay un archivo P13 en esta máquina.
# El panel es sintético, del mismo Pareto/NBD del proyecto.
# PAlive es la probabilidad de seguir originando, no la de pagar.
source("R/00_utils.R")
source("R/simulate.R")
source("R/bnpl_merchants.R")
suppressPackageStartupMessages({
  library(CLVTools)
  library(data.table)
  library(ggplot2)
})
ensure_dirs()

N_MERCHANTS <- 2000L
panel <- simulate_bnpl_merchants(n = N_MERCHANTS, seed = SEED)
tx <- copy(panel$tx)
tx[, Date := format(as.Date(Date), "%Y-%m-%d")]
validate_transactions(tx)

clv <- clvdata(tx, date.format = "ymd", time.unit = TIME_UNIT,
               estimation.split = EST_SPLIT_WEEKS,
               name.id = "Id", name.date = "Date", name.price = "Price")
print(clv)

fit_safe <- function(expr) tryCatch(expr, error = function(e) {
  message("Ajuste fallido: ", conditionMessage(e)); NULL })
fits <- list(
  pnbd    = fit_safe(pnbd(clv,    verbose = FALSE)),
  bgnbd   = fit_safe(bgnbd(clv,   verbose = FALSE)),
  ggomnbd = fit_safe(ggomnbd(clv, verbose = FALSE))
)
fits <- Filter(Negate(is.null), fits)

dated <- as.data.table(panel$tx)
dated[, Date := as.Date(Date)]
dated[, Id := as.character(Id)]
origin <- min(dated$Date)
split_date <- origin + EST_SPLIT_WEEKS * 7
H <- as.numeric(difftime(max(dated$Date), split_date, units = "weeks"))
actual <- dated[Date > split_date, .(actual = .N), by = Id]
est <- dated[Date <= split_date, .(
  n = .N,
  volume = sum(Price),
  first_wk = as.numeric(difftime(min(Date), origin, units = "weeks"))
), by = Id]
est[, naive := (n - 1) / pmax(EST_SPLIT_WEEKS - first_wk, 1e-6) * H]

preds <- rbindlist(lapply(names(fits), function(m) {
  p <- as.data.table(predict(fits[[m]], predict.spending = FALSE, verbose = FALSE))
  p[, Id := as.character(Id)]
  p[, model := m]
  p[, .(Id, model, PAlive, CET)]
}))
preds <- merge(preds, actual, by = "Id", all.x = TRUE)[is.na(actual), actual := 0L]
preds <- merge(preds, est[, .(Id, naive, n, volume)], by = "Id", all.x = TRUE)

metrics <- rbind(
  preds[, .(model, pred = CET, actual)][, .(
    MAE = mae(pred, actual), RMSE = rmse(pred, actual),
    bias = mean(pred) - mean(actual)
  ), by = model],
  preds[model == model[1], .(
    model = "naive_rate",
    MAE = mae(naive, actual), RMSE = rmse(naive, actual),
    bias = mean(naive) - mean(actual)
  )]
)[order(MAE)]
metrics[, H_weeks := H]
metrics[, MAE_per_week := MAE / H]
print(metrics)

pnbd_pred <- preds[model == "pnbd"]
vol_cut <- quantile(pnbd_pred$volume, 0.9)
top <- pnbd_pred[volume >= vol_cut]
palive <- data.table(
  n_merchants = nrow(pnbd_pred),
  mean_palive = mean(pnbd_pred$PAlive),
  share_palive_below_0.5 = mean(pnbd_pred$PAlive < 0.5),
  share_top_volume_below_0.5 = mean(top$PAlive < 0.5),
  mean_actual_low_palive = pnbd_pred[PAlive < 0.5, mean(actual)],
  mean_actual_high_palive = pnbd_pred[PAlive >= 0.5, mean(actual)]
)
print(palive)

truth <- panel$truth
est_coef <- coef(fits$pnbd)
recovery <- data.table(
  param = c("r", "alpha", "s", "beta", "E[lambda]=r/alpha", "E[mu]=s/beta"),
  truth = c(truth$r, truth$alpha, truth$s, truth$beta,
            truth$r / truth$alpha, truth$s / truth$beta),
  estimate = c(est_coef[["r"]], est_coef[["alpha"]], est_coef[["s"]], est_coef[["beta"]],
               est_coef[["r"]] / est_coef[["alpha"]], est_coef[["s"]] / est_coef[["beta"]])
)
recovery[, rel_error := (estimate - truth) / truth]
print(recovery)

cdnow <- fread("outputs/tables/03_holdout_metrics.csv")
cdnow_tx <- load_cdnow_clv()$tx
cdnow_tx[, Date := lubridate::ymd(Date)]
H_cdnow <- as.numeric(difftime(
  max(cdnow_tx$Date), min(cdnow_tx$Date) + EST_SPLIT_WEEKS * 7, units = "weeks"
))
cdnow[, dataset := "cdnow"]
cdnow[, H_weeks := H_cdnow]
cdnow[, MAE_per_week := MAE / H_weeks]
bnpl <- copy(metrics)[, dataset := "bnpl_synthetic"]
versus <- rbind(
  bnpl[, .(dataset, model, MAE, RMSE, bias, H_weeks, MAE_per_week)],
  cdnow[, .(dataset, model, MAE, RMSE, bias, H_weeks, MAE_per_week)],
  fill = TRUE
)

fwrite(metrics, "outputs/tables/11_holdout_metrics.csv")
fwrite(palive, "outputs/tables/11_palive_summary.csv")
fwrite(recovery, "outputs/tables/11_parameter_recovery.csv")
fwrite(versus, "outputs/tables/11_vs_cdnow.csv")

p <- ggplot(pnbd_pred, aes(PAlive)) +
  geom_histogram(bins = 20, fill = "gray35", color = "white") +
  labs(x = "P(seguir originando)", y = "Comercios",
       title = "Comercios sintéticos BNPL, Pareto/NBD") +
  theme_bw()
ggsave("outputs/figures/11_palive.png", p, width = 8, height = 4.5, dpi = 150)
cat("11 OK\n")
