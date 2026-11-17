# archivo: R/10_online_retail.R
# Fase B. Online Retail II (UCI) con el mismo diseño que CDNOW:
# cohorte de las primeras 13 semanas, corte a las 39, holdout de 39.
# El xlsx no se versiona (data/raw/ está en .gitignore).
# Fuente: https://archive.ics.uci.edu/ml/machine-learning-databases/00502/online_retail_II.xlsx
source("R/00_utils.R")
source("R/retail_prepare.R")
suppressPackageStartupMessages({
  library(CLVTools)
  library(data.table)
  library(ggplot2)
  library(readxl)
})
ensure_dirs()
set.seed(SEED)

FIRST_WEEKS <- 13
H_HOLD <- 39
raw_path <- "data/raw/online_retail_II.xlsx"
stopifnot("falta data/raw/online_retail_II.xlsx" = file.exists(raw_path))

raw <- rbindlist(lapply(excel_sheets(raw_path), function(s) {
  as.data.table(read_excel(raw_path, sheet = s))
}), fill = TRUE)
prep <- prepare_retail_transactions(
  raw,
  first_weeks = FIRST_WEEKS,
  split_weeks = EST_SPLIT_WEEKS,
  horizon_weeks = H_HOLD
)
tx <- copy(prep$tx)
tx[, Date := format(Date, "%Y-%m-%d")]
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

comparison <- rbindlist(lapply(names(fits), function(m) {
  f <- fits[[m]]
  data.table(model = m, logLik = as.numeric(logLik(f)),
             AIC = AIC(f), BIC = BIC(f), n_customers = nobs(f))
}))[order(AIC)]
print(comparison)

dated <- copy(prep$tx)
origin <- min(dated$Date)
split_date <- origin + EST_SPLIT_WEEKS * 7
H <- as.numeric(difftime(max(dated$Date), split_date, units = "weeks"))
actual <- dated[Date > split_date, .(actual = .N), by = Id]
actual[, Id := as.character(Id)]
est <- dated[Date <= split_date,
             .(n = .N,
               first_wk = as.numeric(difftime(min(Date), origin, units = "weeks"))),
             by = Id]
est[, naive := (n - 1) / pmax(EST_SPLIT_WEEKS - first_wk, 1e-6) * H]
est[, Id := as.character(Id)]

preds <- rbindlist(lapply(names(fits), function(m) {
  p <- as.data.table(predict(fits[[m]], predict.spending = FALSE, verbose = FALSE))
  p[, Id := as.character(Id)]
  p[, model := m]
  p[, .(Id, model, CET)]
}))
preds <- merge(preds, actual, by = "Id", all.x = TRUE)[is.na(actual), actual := 0L]
preds <- merge(preds, est[, .(Id, naive)], by = "Id", all.x = TRUE)

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

calib <- preds[model == "pnbd", decile_calibration(CET, actual)]
print(calib)

spend <- gg(clv, verbose = FALSE)
clv_pred <- as.data.table(predict(
  fits$pnbd, predict.spending = spend, prediction.end = 52,
  continuous.discount.factor = disc_per_unit(), verbose = FALSE
))
setorder(clv_pred, -predicted.CLV)
top_n <- ceiling(nrow(clv_pred) * 0.10)
top_share <- sum(head(clv_pred$predicted.CLV, top_n)) / sum(clv_pred$predicted.CLV)
cat(sprintf("Decil superior concentra %.1f%% del CLV\n", 100 * top_share))

ggom_b <- if ("ggomnbd" %in% names(fits)) unname(coef(fits$ggomnbd)[["b"]]) else NA_real_
cohort <- data.table(
  origin = as.character(origin),
  end = as.character(max(dated$Date)),
  n_input = prep$n_input,
  n_missing_id = prep$n_missing_id,
  n_invoices = prep$n_invoices,
  n_identified = prep$n_identified,
  n_cohort = prep$n_cohort,
  n_transactions = nrow(dated),
  first_weeks = FIRST_WEEKS,
  split_weeks = EST_SPLIT_WEEKS,
  H_weeks = H,
  aic_winner = comparison$model[1],
  holdout_winner = metrics$model[1],
  ggom_b = ggom_b,
  top_decile_clv_share = top_share
)
print(cohort)

cdnow_tx <- load_cdnow_clv()$tx
cdnow_tx[, Date := lubridate::ymd(Date)]
cdnow_origin <- min(cdnow_tx$Date)
cdnow_split <- cdnow_origin + EST_SPLIT_WEEKS * 7
H_cdnow <- as.numeric(difftime(max(cdnow_tx$Date), cdnow_split, units = "weeks"))
cdnow <- fread("outputs/tables/03_holdout_metrics.csv")
cdnow[, dataset := "cdnow"]
cdnow[, H_weeks := H_cdnow]
cdnow[, MAE_per_week := MAE / H_weeks]
retail_cmp <- copy(metrics)[, dataset := "online_retail_ii"]
versus <- rbind(
  retail_cmp[, .(dataset, model, MAE, RMSE, bias, H_weeks, MAE_per_week)],
  cdnow[, .(dataset, model, MAE, RMSE, bias, H_weeks, MAE_per_week)],
  fill = TRUE
)
print(versus)

fwrite(comparison, "outputs/tables/10_model_comparison.csv")
fwrite(metrics, "outputs/tables/10_holdout_metrics.csv")
fwrite(calib, "outputs/tables/10_calibration_pnbd_deciles.csv")
fwrite(cohort, "outputs/tables/10_cohort_summary.csv")
fwrite(versus, "outputs/tables/10_vs_cdnow.csv")

cal_long <- melt(calib, id.vars = "bin",
                 measure.vars = c("mean_pred", "mean_actual"),
                 variable.name = "serie", value.name = "compras")
cal_long[, serie := fifelse(serie == "mean_pred", "Predicho", "Observado")]
p <- ggplot(cal_long, aes(factor(bin), compras, fill = serie)) +
  geom_col(position = "dodge") +
  labs(x = "Decil de CET", y = "Compras medias en el holdout", fill = NULL,
       title = "Online Retail II, Pareto/NBD") +
  theme_bw()
ggsave("outputs/figures/10_calibration_pnbd.png", p, width = 8, height = 4.5, dpi = 150)
cat("10 OK\n")
