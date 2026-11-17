# archivo: R/03_holdout_validation.R
source("R/00_utils.R")
suppressPackageStartupMessages({ library(CLVTools); library(data.table) })
ensure_dirs()

d    <- load_cdnow_clv()
fits <- readRDS("outputs/models/fits_cdnow.rds")

# --- Realidad observada en el holdout (calculada de forma independiente) -----
tx <- copy(d$tx)[, Date := lubridate::ymd(Date)]
origin     <- min(tx$Date)
split_date <- origin + EST_SPLIT_WEEKS * 7
H          <- as.numeric(difftime(max(tx$Date), split_date, units = "weeks"))
actual     <- tx[Date > split_date, .(actual = .N), by = Id]
actual[, Id := as.character(Id)]

# --- Baseline ingenuo: extrapolar la tasa de compra repetida observada --------
est <- tx[Date <= split_date,
          .(n = .N, first_wk = as.numeric(difftime(min(Date), origin, units = "weeks"))),
          by = Id]
est[, naive := (n - 1) / pmax(EST_SPLIT_WEEKS - first_wk, 1e-6) * H]
est[, Id := as.character(Id)]

# --- Predicciones de cada modelo para el holdout ------------------------------
preds <- rbindlist(lapply(names(fits), function(m) {
  p <- as.data.table(predict(fits[[m]], predict.spending = FALSE, verbose = FALSE))
  p[, Id := as.character(Id)]
  p[, model := m]
  p[, .(Id, model, PAlive, CET)]
}))
preds <- merge(preds, actual, by = "Id", all.x = TRUE)[is.na(actual), actual := 0L]
preds <- merge(preds, est[, .(Id, naive)], by = "Id", all.x = TRUE)

metrics <- rbind(
  preds[, .(model, pred = CET, actual)][, .(MAE = mae(pred, actual), RMSE = rmse(pred, actual),
                                            bias = mean(pred) - mean(actual)), by = model],
  preds[model == model[1], .(model = "naive_rate",
                             MAE = mae(naive, actual), RMSE = rmse(naive, actual),
                             bias = mean(naive) - mean(actual))]
)[order(MAE)]
print(metrics)

calib <- preds[model == "pnbd", decile_calibration(CET, actual)]
print(calib)

fwrite(metrics, "outputs/tables/03_holdout_metrics.csv")
fwrite(calib,   "outputs/tables/03_calibration_pnbd_deciles.csv")
saveRDS(preds,  "outputs/models/holdout_preds.rds")

# Seguimiento agregado: transacciones acumuladas reales vs. modelo
ggplot2::ggsave("outputs/figures/03_tracking_pnbd.png",
                plot(fits$pnbd, which = "tracking", cumulative = TRUE),
                width = 8, height = 4.5, dpi = 150)
cat("03 OK\n")
