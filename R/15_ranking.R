# archivo: R/15_ranking.R
# Hipótesis fijada antes de mirar el resultado:
# en diciembre y en junio, el Spearman del BG/NBD y del Pareto/NBD
# con las compras observadas supera al de la tasa histórica.
# Mismas ventanas y la misma cohorte que R/14_seasonality.R.
# El xlsx no se versiona.
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

safe_spearman <- function(pred, actual) {
  if (length(unique(pred)) < 2 || length(unique(actual)) < 2) return(NA_real_)
  suppressWarnings(cor(pred, actual, method = "spearman"))
}

raw_path <- "data/raw/online_retail_II.xlsx"
stopifnot("falta data/raw/online_retail_II.xlsx" = file.exists(raw_path))
raw <- rbindlist(lapply(excel_sheets(raw_path), function(s) {
  as.data.table(read_excel(raw_path, sheet = s))
}), fill = TRUE)
prep <- prepare_retail_transactions(
  raw, first_weeks = 13, split_weeks = EST_SPLIT_WEEKS, horizon_weeks = 48
)
tx <- copy(prep$tx)
origin <- min(tx$Date)
split_date <- origin + EST_SPLIT_WEEKS * 7
windows <- data.table(
  window = c("diciembre", "junio"),
  target_start = as.Date(c("2010-12-01", "2011-06-01")),
  target_end = as.Date(c("2010-12-29", "2011-06-29")),
  hist_start = as.Date(c("2009-12-01", "2010-06-01")),
  hist_end = as.Date(c("2009-12-29", "2010-06-29"))
)
windows[, `:=`(
  t0 = as.numeric(difftime(target_start, split_date, units = "weeks")),
  t1 = as.numeric(difftime(target_end, split_date, units = "weeks"))
)]

clv_tx <- copy(tx)
clv_tx[, Date := format(Date, "%Y-%m-%d")]
validate_transactions(clv_tx)
clv <- clvdata(clv_tx, date.format = "ymd", time.unit = TIME_UNIT,
               estimation.split = EST_SPLIT_WEEKS,
               name.id = "Id", name.date = "Date", name.price = "Price")
fit_safe <- function(expr) tryCatch(expr, error = function(e) {
  message("Ajuste fallido: ", conditionMessage(e)); NULL })
fits <- Filter(Negate(is.null), list(
  pnbd = fit_safe(pnbd(clv, verbose = FALSE)),
  bgnbd = fit_safe(bgnbd(clv, verbose = FALSE)),
  ggomnbd = fit_safe(ggomnbd(clv, verbose = FALSE))
))
cet_until <- function(fit, weeks) {
  p <- as.data.table(predict(fit, predict.spending = FALSE,
                             prediction.end = weeks, verbose = FALSE))
  p[, .(Id = as.character(Id), CET)]
}
est <- tx[Date <= split_date, .(
  n = .N,
  first_wk = as.numeric(difftime(min(Date), origin, units = "weeks"))
), by = Id]
est[, Id := as.character(Id)]

score_one <- function(pred, actual, repeat_id) {
  data.table(
    spearman_all = safe_spearman(pred, actual),
    spearman_repeat = safe_spearman(pred[repeat_id], actual[repeat_id]),
    mae_all = mae(pred, actual),
    mae_repeat = mae(pred[repeat_id], actual[repeat_id]),
    share_active = mean(actual > 0)
  )
}

score_window <- function(w) {
  H <- w$t1 - w$t0
  actual <- count_between(tx, w$target_start, w$target_end)
  actual[, Id := as.character(Id)]
  hist <- count_between(tx, w$hist_start, w$hist_end)
  hist[, Id := as.character(Id)]
  base <- est[, .(Id, n, naive = (n - 1) / pmax(EST_SPLIT_WEEKS - first_wk, 1e-6) * H)]
  base <- merge(base, hist[, .(Id, seasonal = y)], by = "Id", all.x = TRUE)
  base[is.na(seasonal), seasonal := 0]
  base <- merge(base, actual[, .(Id, y)], by = "Id", all.x = TRUE)
  base[is.na(y), y := 0]
  repeat_id <- base$n >= 2

  rows <- rbindlist(lapply(names(fits), function(m) {
    a <- cet_until(fits[[m]], w$t1)
    b <- cet_until(fits[[m]], w$t0)
    p <- merge(a, b, by = "Id", suffixes = c("_1", "_0"))
    p[, pred := CET_1 - CET_0]
    p <- merge(base[, .(Id, y, n)], p, by = "Id", all.x = TRUE)
    sc <- score_one(p$pred, p$y, p$n >= 2)
    sc[, `:=`(window = w$window, model = m)]
    sc
  }))
  naive_sc <- score_one(base$naive, base$y, repeat_id)
  seas_sc <- score_one(base$seasonal, base$y, repeat_id)
  rbind(
    rows,
    cbind(data.table(window = w$window, model = "naive_rate"), naive_sc),
    cbind(data.table(window = w$window, model = "seasonal"), seas_sc)
  )
}

metrics <- rbindlist(lapply(seq_len(nrow(windows)), function(i) score_window(windows[i])))
setorder(metrics, window, -spearman_all)
print(metrics)
fwrite(metrics, "outputs/tables/15_ranking.csv")

p <- ggplot(metrics, aes(reorder(model, spearman_all), spearman_all, fill = window)) +
  geom_col(position = "dodge") +
  labs(x = NULL, y = "Spearman con las compras observadas", fill = NULL,
       title = "Quién compra, no cuánto erra el conteo") +
  theme_bw()
ggsave("outputs/figures/15_ranking.png", p, width = 8, height = 4.5, dpi = 150)
cat("15 OK\n")
