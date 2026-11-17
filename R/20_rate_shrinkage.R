# archivo: R/20_rate_shrinkage.R
# Hipótesis fijada antes de mirar el error:
# en los clientes con 6 o más compras y última compra en la segunda
# mitad, se parte por la mediana de (n - 1) / edad. El empate va a la
# mitad alta. La mediana usa solo la estimación.
# En las dos mitades el BG/NBD predice menos que la tasa (n - 1) / 39.
# El exceso de esa tasa (media predicha menos media observada) es mayor
# en la mitad alta que en la baja.
# En la mitad alta, multiplicar la tasa por la P(activo) del BG/NBD
# deja la predicción media por encima de la del BG/NBD.
# Mismos datos y el mismo corte que R/19_recency_gap.R.
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
  actual <- tx[Date > split_date, .(actual = .N), by = Id]
  est <- tx[Date <= split_date, .(
    n = .N,
    first_wk = as.numeric(difftime(min(Date), origin, units = "weeks")),
    last_wk = as.numeric(difftime(max(Date), origin, units = "weeks"))
  ), by = Id]
  est[, age := pmax(EST_SPLIT_WEEKS - first_wk, 1e-6)]
  est[, rate := (n - 1) / age]
  est[, naive := rate * H]
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
  preds <- merge(preds, actual, by = "Id", all.x = TRUE)[is.na(actual), actual := 0]
  merge(preds, est, by = "Id", all.x = TRUE)
}

cell_rows <- function(dataset, cell, x, cut) {
  if (nrow(x) == 0) return(data.table())
  pred <- list(
    pnbd = x$pred_pnbd,
    bgnbd = x$pred_bgnbd,
    naive_calendar = x$naive_calendar,
    calendar_x_bgnbd = x$naive_calendar * x$palive_bgnbd,
    calendar_x_pnbd = x$naive_calendar * x$palive_pnbd
  )
  palive <- list(
    pnbd = x$palive_pnbd,
    bgnbd = x$palive_bgnbd,
    naive_calendar = rep(NA_real_, nrow(x)),
    calendar_x_bgnbd = x$palive_bgnbd,
    calendar_x_pnbd = x$palive_pnbd
  )
  rbindlist(lapply(names(pred), function(m) {
    data.table(
      dataset = dataset, cell = cell, model = m,
      n_customers = nrow(x), cut_rate = cut,
      mean_rate = mean(x$rate), mean_actual = mean(x$actual),
      mean_pred = mean(pred[[m]]),
      bias = mean(pred[[m]]) - mean(x$actual),
      MAE = mae(pred[[m]], x$actual),
      mean_palive = mean(palive[[m]])
    )
  }))
}

score_dataset <- function(dataset, tx) {
  d <- prepare_preds(tx)
  wide <- dcast(
    d,
    Id + n + age + rate + naive + naive_calendar + bin + recency + actual ~ model,
    value.var = c("pred", "palive")
  )
  need <- c("pred_pnbd", "pred_bgnbd", "palive_pnbd", "palive_bgnbd")
  stopifnot("dcast sin columnas de modelo" = all(need %in% names(wide)))
  recent <- wide[bin == "6+" & recency == "recent"]
  cut <- median(recent$rate)
  recent[, half := fifelse(rate >= cut, "recent_high", "recent_low")]
  rbind(
    cell_rows(dataset, "recent_low", recent[half == "recent_low"], cut),
    cell_rows(dataset, "recent_high", recent[half == "recent_high"], cut),
    cell_rows(dataset, "recent_all", recent, cut)
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
out[, model := factor(model, levels = c(
  "naive_calendar", "calendar_x_bgnbd", "calendar_x_pnbd", "bgnbd", "pnbd"
))]
setorder(out, dataset, cell, model)
print(out)
fwrite(out, "outputs/tables/20_rate_shrinkage.csv")

p <- ggplot(out[cell != "recent_all"], aes(cell, bias, fill = model)) +
  geom_col(position = "dodge") +
  facet_wrap(~ dataset, scales = "free_y") +
  labs(x = NULL, y = "Predicción media − observado", fill = NULL,
       title = "Compradores recientes con seis o más, según su tasa") +
  theme_bw()
ggsave("outputs/figures/20_rate_shrinkage.png", p, width = 8, height = 4.5, dpi = 150)
cat("20 OK\n")
