# archivo: R/22_purchase_pace.R
# Hipótesis fijada antes de mirar el intervalo:
# en la mitad alta de R/20_rate_shrinkage.R, entre quienes compran al
# menos dos veces en el holdout, la mediana de (intervalo del holdout
# menos intervalo de la estimación) es menor o igual que cero. El
# intervalo es el tiempo entre la primera y la última compra, dividido
# por las compras menos una. No incluye el silencio posterior a la
# última. Un mismo día cuenta como 1/7 de semana.
# Si eso se cumple, el faltante de compras de la fase 21 es tiempo sin
# comprar, no un ritmo más lento mientras compran.
# Mismo corte y la misma mediana que R/21_active_holdout.R.
source("R/00_utils.R")
source("R/retail_prepare.R")
source("R/frequency_bins.R")
suppressPackageStartupMessages({
  library(CLVTools)
  library(data.table)
  library(ggplot2)
  library(readxl)
})
ensure_dirs()
set.seed(SEED)

fit_safe <- function(expr) tryCatch(expr, error = function(e) {
  message("Ajuste fallido: ", conditionMessage(e)); NULL })

prepare_preds <- function(tx) {
  tx <- as.data.table(tx)
  tx[, Date := as.Date(Date)]
  tx[, Id := as.character(Id)]
  origin <- min(tx$Date)
  split_date <- origin + EST_SPLIT_WEEKS * 7
  H <- as.numeric(difftime(max(tx$Date), split_date, units = "weeks"))
  hold <- tx[Date > split_date, .(
    actual = .N,
    first_h = min(Date),
    last_h = max(Date)
  ), by = Id]
  est <- tx[Date <= split_date, .(
    n = .N,
    first_wk = as.numeric(difftime(min(Date), origin, units = "weeks")),
    last_wk = as.numeric(difftime(max(Date), origin, units = "weeks"))
  ), by = Id]
  est[, age := pmax(EST_SPLIT_WEEKS - first_wk, 1e-6)]
  est[, rate := (n - 1) / age]
  est[, est_gap := pmax(last_wk - first_wk, 1 / 7) / (n - 1)]
  est[, naive_calendar := (n - 1) / EST_SPLIT_WEEKS * H]
  est[, bin := frequency_bin(n)]
  est[, recency := fifelse(last_wk < EST_SPLIT_WEEKS / 2, "silent", "recent")]

  clv_tx <- copy(tx)
  clv_tx[, Date := format(Date, "%Y-%m-%d")]
  validate_transactions(clv_tx)
  clv <- clvdata(clv_tx, date.format = "ymd", time.unit = TIME_UNIT,
                 estimation.split = EST_SPLIT_WEEKS,
                 name.id = "Id", name.date = "Date", name.price = "Price")
  fits <- Filter(Negate(is.null), list(
    pnbd = fit_safe(pnbd(clv, verbose = FALSE)),
    bgnbd = fit_safe(bgnbd(clv, verbose = FALSE))
  ))
  stopifnot("faltan pnbd o bgnbd" = all(c("pnbd", "bgnbd") %in% names(fits)))
  preds <- rbindlist(lapply(names(fits), function(m) {
    p <- as.data.table(predict(fits[[m]], predict.spending = FALSE, verbose = FALSE))
    p[, .(Id = as.character(Id), model = m, pred = CET, palive = PAlive)]
  }))
  preds <- merge(preds, hold, by = "Id", all.x = TRUE)[is.na(actual), actual := 0]
  merge(preds, est, by = "Id", all.x = TRUE)
}

slice_rows <- function(dataset, cell, slice, x) {
  pace <- slice == "pace" && nrow(x) > 0
  data.table(
    dataset = dataset, cell = cell, slice = slice,
    n_customers = nrow(x),
    mean_actual = if (nrow(x)) mean(x$actual) else NA_real_,
    mean_calendar = if (nrow(x)) mean(x$naive_calendar) else NA_real_,
    mean_bgnbd = if (nrow(x)) mean(x$pred_bgnbd) else NA_real_,
    mean_pnbd = if (nrow(x)) mean(x$pred_pnbd) else NA_real_,
    median_est_gap = if (pace) median(x$est_gap) else NA_real_,
    median_hold_gap = if (pace) median(x$hold_gap) else NA_real_,
    median_gap_diff = if (pace) median(x$hold_gap - x$est_gap) else NA_real_,
    mean_est_gap = if (pace) mean(x$est_gap) else NA_real_,
    mean_hold_gap = if (pace) mean(x$hold_gap) else NA_real_,
    share_slower = if (pace) mean(x$hold_gap > x$est_gap) else NA_real_
  )
}

score_half <- function(dataset, cell, x) {
  rbind(
    slice_rows(dataset, cell, "return", x[actual >= 1]),
    slice_rows(dataset, cell, "once", x[actual == 1]),
    slice_rows(dataset, cell, "pace", x[actual >= 2])
  )
}

score_dataset <- function(dataset, tx) {
  d <- prepare_preds(tx)
  wide <- dcast(
    d,
    Id + n + rate + est_gap + naive_calendar + bin + recency + actual + first_h + last_h ~ model,
    value.var = c("pred", "palive")
  )
  need <- c("pred_pnbd", "pred_bgnbd")
  stopifnot("dcast sin columnas de modelo" = all(need %in% names(wide)))
  wide[, first_h := as.Date(first_h)]
  wide[, last_h := as.Date(last_h)]
  wide[, span := pmax(as.numeric(difftime(last_h, first_h, units = "weeks")), 1 / 7)]
  wide[, hold_gap := NA_real_]
  wide[actual >= 2, hold_gap := span / (actual - 1)]
  recent <- wide[bin == "6+" & recency == "recent"]
  cut <- median(recent$rate)
  recent[, half := fifelse(rate >= cut, "recent_high", "recent_low")]
  rbind(
    score_half(dataset, "recent_low", recent[half == "recent_low"]),
    score_half(dataset, "recent_high", recent[half == "recent_high"]),
    score_half(dataset, "recent_all", recent)
  )
}

cd <- load_cdnow_clv()$tx
cd[, Date := lubridate::ymd(Date)]
raw_path <- "data/raw/online_retail_II.xlsx"
stopifnot("falta data/raw/online_retail_II.xlsx" = file.exists(raw_path))
raw <- rbindlist(lapply(excel_sheets(raw_path), function(s) {
  as.data.table(read_excel(raw_path, sheet = s))
}), fill = TRUE)
retail <- prepare_retail_transactions(
  raw, first_weeks = 13, split_weeks = EST_SPLIT_WEEKS, horizon_weeks = 39
)$tx

out <- rbind(score_dataset("cdnow", cd), score_dataset("online_retail_ii", retail))
out[, cell := factor(cell, levels = c("recent_low", "recent_high", "recent_all"))]
out[, slice := factor(slice, levels = c("return", "once", "pace"))]
setorder(out, dataset, cell, slice)
print(out)
fwrite(out, "outputs/tables/22_purchase_pace.csv")

pace <- out[slice == "pace" & cell != "recent_all"]
long <- melt(
  pace,
  id.vars = c("dataset", "cell"),
  measure.vars = c("median_est_gap", "median_hold_gap"),
  variable.name = "which",
  value.name = "weeks"
)
long[, which := fifelse(which == "median_est_gap", "estimacion", "holdout")]
p <- ggplot(long, aes(cell, weeks, fill = which)) +
  geom_col(position = "dodge") +
  facet_wrap(~ dataset) +
  labs(x = NULL, y = "Mediana de semanas entre compras", fill = NULL,
       title = "Ritmo entre la primera y la última compra") +
  theme_bw()
ggsave("outputs/figures/22_purchase_pace.png", p, width = 8, height = 4.5, dpi = 150)
cat("22 OK\n")
