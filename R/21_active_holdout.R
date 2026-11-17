# archivo: R/21_active_holdout.R
# Hipótesis fijada antes de mirar el error:
# en la mitad alta de los clientes con 6 o más compras y última compra
# en la segunda mitad (mediana de (n - 1) / edad, empate a la alta),
# el exceso de la tasa (n - 1) / 39 desaparece si se deja solo a quienes
# compran al menos una vez en el holdout. En ese subconjunto la media
# de la tasa es menor o igual que la media observada, y el BG/NBD queda
# por debajo de la tasa. El corte es el mismo que R/20_rate_shrinkage.R.
# Mirar solo a quien vuelve es una descomposición, no un pronóstico.
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

cell_rows <- function(dataset, cell, subset, x, n_parent) {
  if (nrow(x) == 0) return(data.table())
  pred <- list(
    naive_calendar = x$naive_calendar,
    bgnbd = x$pred_bgnbd,
    pnbd = x$pred_pnbd
  )
  rbindlist(lapply(names(pred), function(m) {
    data.table(
      dataset = dataset, cell = cell, subset = subset, model = m,
      n_customers = nrow(x), n_parent = n_parent,
      mean_actual = mean(x$actual), mean_pred = mean(pred[[m]]),
      bias = mean(pred[[m]]) - mean(x$actual),
      MAE = mae(pred[[m]], x$actual),
      mean_palive_bgnbd = mean(x$palive_bgnbd)
    )
  }))
}

score_half <- function(dataset, cell, x) {
  rbind(
    cell_rows(dataset, cell, "all", x, nrow(x)),
    cell_rows(dataset, cell, "active", x[actual >= 1], nrow(x))
  )
}

score_dataset <- function(dataset, tx) {
  d <- prepare_preds(tx)
  wide <- dcast(
    d,
    Id + n + age + rate + naive_calendar + bin + recency + actual ~ model,
    value.var = c("pred", "palive")
  )
  need <- c("pred_pnbd", "pred_bgnbd", "palive_bgnbd")
  stopifnot("dcast sin columnas de modelo" = all(need %in% names(wide)))
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
out[, subset := factor(subset, levels = c("all", "active"))]
out[, model := factor(model, levels = c("naive_calendar", "bgnbd", "pnbd"))]
setorder(out, dataset, cell, subset, model)
print(out)
fwrite(out, "outputs/tables/21_active_holdout.csv")

p <- ggplot(out[cell != "recent_all"], aes(cell, bias, fill = model)) +
  geom_col(position = "dodge") +
  facet_grid(subset ~ dataset, scales = "free_y") +
  labs(x = NULL, y = "Predicción media − observado", fill = NULL,
       title = "Misma tasa, con y sin los que no vuelven") +
  theme_bw()
ggsave("outputs/figures/21_active_holdout.png", p, width = 8, height = 5.5, dpi = 150)
cat("21 OK\n")
