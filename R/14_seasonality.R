# archivo: R/14_seasonality.R
# Hipótesis fijada antes de mirar el error:
# en las 4 semanas de diciembre, repetir el diciembre anterior empata o gana
# a los BTYD; en las 4 semanas de junio, los BTYD bajan el MAE del baseline
# de tasa. Misma cohorte y mismo corte de 39 semanas que la fase 10.
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

raw_path <- "data/raw/online_retail_II.xlsx"
stopifnot("falta data/raw/online_retail_II.xlsx" = file.exists(raw_path))
raw <- rbindlist(lapply(excel_sheets(raw_path), function(s) {
  as.data.table(read_excel(raw_path, sheet = s))
}), fill = TRUE)

# 48 semanas de holdout alcanzan junio de 2011 (semana ~82 desde el origen).
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
print(windows[, .(window, target_start, target_end, t0, t1)])
stopifnot("la ventana sale antes del corte" = all(windows$t0 > 0))
stopifnot("junio no cabe en los datos guardados" =
            max(windows$target_end) <= prep$end_date)

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

score_window <- function(w) {
  t0 <- w$t0
  t1 <- w$t1
  H <- t1 - t0
  actual <- count_between(tx, w$target_start, w$target_end)
  actual[, Id := as.character(Id)]
  hist <- count_between(tx, w$hist_start, w$hist_end)
  hist[, Id := as.character(Id)]
  base <- est[, .(Id, naive = (n - 1) / pmax(EST_SPLIT_WEEKS - first_wk, 1e-6) * H)]
  base <- merge(base, hist[, .(Id, seasonal = y)], by = "Id", all.x = TRUE)
  base[is.na(seasonal), seasonal := 0]

  rows <- rbindlist(lapply(names(fits), function(m) {
    a <- cet_until(fits[[m]], t1)
    b <- cet_until(fits[[m]], t0)
    p <- merge(a, b, by = "Id", suffixes = c("_1", "_0"))
    p[, pred := CET_1 - CET_0]
    p <- merge(p, actual[, .(Id, y)], by = "Id", all.x = TRUE)
    p[is.na(y), y := 0]
    data.table(window = w$window, model = m,
               MAE = mae(p$pred, p$y),
               bias = mean(p$pred) - mean(p$y),
               mean_actual = mean(p$y))
  }))
  both <- merge(base, actual[, .(Id, y)], by = "Id", all.x = TRUE)
  both[is.na(y), y := 0]
  rbind(rows, data.table(
    window = w$window,
    model = c("naive_rate", "seasonal"),
    MAE = c(mae(both$naive, both$y), mae(both$seasonal, both$y)),
    bias = c(mean(both$naive) - mean(both$y), mean(both$seasonal) - mean(both$y)),
    mean_actual = mean(both$y)
  ))
}

metrics <- rbindlist(lapply(seq_len(nrow(windows)), function(i) score_window(windows[i])))
setorder(metrics, window, MAE)
print(metrics)
fwrite(metrics, "outputs/tables/14_seasonality_mae.csv")

p <- ggplot(metrics, aes(reorder(model, MAE), MAE, fill = window)) +
  geom_col(position = "dodge") +
  labs(x = NULL, y = "MAE", fill = NULL,
       title = "Cuatro semanas de diciembre y de junio") +
  theme_bw()
ggsave("outputs/figures/14_seasonality_mae.png", p, width = 8, height = 4.5, dpi = 150)
cat("14 OK\n")
