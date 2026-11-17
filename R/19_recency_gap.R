# archivo: R/19_recency_gap.R
# Hipótesis fijada antes de mirar el error:
# el exceso que queda al dividir (n - 1) entre 39 semanas, en el tramo
# de 6 o más compras, está en quienes no vuelven a comprar desde la
# primera mitad (last_wk < EST_SPLIT_WEEKS / 2). Ahí el BG/NBD tiene
# menor MAE que esa tasa. Quienes compran en la segunda mitad siguen
# activos: ahí la tasa sobre 39 semanas empata o gana al BG/NBD.
# Mismos datos y el mismo corte que R/18_short_age.R.
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
  est[, naive := (n - 1) / age * H]
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
  preds <- rbindlist(lapply(names(fits), function(m) {
    p <- as.data.table(predict(fits[[m]], predict.spending = FALSE, verbose = FALSE))
    p[, .(Id = as.character(Id), model = m, pred = CET, palive = PAlive)]
  }))
  preds <- merge(preds, actual, by = "Id", all.x = TRUE)[is.na(actual), actual := 0]
  merge(preds, est, by = "Id", all.x = TRUE)
}

cell_mae <- function(dataset, cell, d) {
  if (nrow(d) == 0) return(data.table())
  rows <- rbindlist(lapply(c("pnbd", "bgnbd"), function(m) {
    x <- d[model == m]
    data.table(dataset = dataset, cell = cell, model = m,
               n_customers = nrow(x), mean_n = mean(x$n),
               mean_last_wk = mean(x$last_wk),
               mean_actual = mean(x$actual), mean_pred = mean(x$pred),
               MAE = mae(x$pred, x$actual), mean_palive = mean(x$palive))
  }))
  base <- d[model == "pnbd"]
  rbind(rows, data.table(
    dataset = dataset, cell = cell,
    model = c("naive_rate", "naive_calendar"),
    n_customers = nrow(base),
    mean_n = mean(base$n),
    mean_last_wk = mean(base$last_wk),
    mean_actual = mean(base$actual),
    mean_pred = c(mean(base$naive), mean(base$naive_calendar)),
    MAE = c(mae(base$naive, base$actual), mae(base$naive_calendar, base$actual)),
    mean_palive = NA_real_
  ))
}

score_dataset <- function(dataset, tx) {
  d <- prepare_preds(tx)
  heavy <- d[bin == "6+"]
  rbind(
    cell_mae(dataset, "6+_silent", heavy[recency == "silent"]),
    cell_mae(dataset, "6+_recent", heavy[recency == "recent"])
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
out[, cell := factor(cell, levels = c("6+_silent", "6+_recent"))]
setorder(out, dataset, cell, MAE)
print(out)
fwrite(out, "outputs/tables/19_recency_gap.csv")

p <- ggplot(out, aes(cell, MAE, fill = model)) +
  geom_col(position = "dodge") +
  facet_wrap(~ dataset, scales = "free_y") +
  labs(x = NULL, y = "MAE en el holdout", fill = NULL,
       title = "Seis o más compras, según la última compra") +
  theme_bw()
ggsave("outputs/figures/19_recency_gap.png", p, width = 8, height = 4.5, dpi = 150)
cat("19 OK\n")
