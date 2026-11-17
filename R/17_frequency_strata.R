# archivo: R/17_frequency_strata.R
# Hipótesis fijada antes de mirar el error:
# con una sola compra en la estimación, Pareto/NBD y BG/NBD tienen menor MAE
# que la tasa histórica; con 6 o más, la tasa histórica empata o gana.
# Mismos cortes de 39 semanas en CDNOW y en la cohorte de Online Retail.
# Tramos: 1, 2, 3-5, 6+.
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

strata_for <- function(dataset, tx) {
  tx <- as.data.table(tx)
  tx[, Date := as.Date(Date)]
  tx[, Id := as.character(Id)]
  origin <- min(tx$Date)
  split_date <- origin + EST_SPLIT_WEEKS * 7
  H <- as.numeric(difftime(max(tx$Date), split_date, units = "weeks"))
  actual <- tx[Date > split_date, .(actual = .N), by = Id]
  est <- tx[Date <= split_date, .(
    n = .N,
    first_wk = as.numeric(difftime(min(Date), origin, units = "weeks"))
  ), by = Id]
  est[, naive := (n - 1) / pmax(EST_SPLIT_WEEKS - first_wk, 1e-6) * H]
  est[, bin := frequency_bin(n)]

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
    p[, .(Id = as.character(Id), model = m, pred = CET)]
  }))
  preds <- merge(preds, actual, by = "Id", all.x = TRUE)[is.na(actual), actual := 0]
  preds <- merge(preds, est[, .(Id, n, bin, naive)], by = "Id", all.x = TRUE)

  model_rows <- preds[, .(
    n_customers = .N,
    mean_actual = mean(actual),
    mean_pred = mean(pred),
    MAE = mae(pred, actual)
  ), by = .(bin, model)]
  model_rows[, dataset := dataset]
  naive_rows <- preds[model == names(fits)[1], .(
    n_customers = .N,
    mean_actual = mean(actual),
    mean_pred = mean(naive),
    MAE = mae(naive, actual)
  ), by = bin]
  naive_rows[, `:=`(dataset = dataset, model = "naive_rate")]
  rbind(
    model_rows[, .(dataset, bin, model, n_customers, mean_actual, mean_pred, MAE)],
    naive_rows[, .(dataset, bin, model, n_customers, mean_actual, mean_pred, MAE)]
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

out <- rbind(
  strata_for("cdnow", cd),
  strata_for("online_retail_ii", retail)
)
bin_order <- c("1", "2", "3-5", "6+")
out[, bin := factor(bin, levels = bin_order)]
setorder(out, dataset, bin, MAE)
print(out)
fwrite(out, "outputs/tables/17_mae_by_frequency.csv")

p <- ggplot(out[model %in% c("pnbd", "bgnbd", "naive_rate")],
            aes(bin, MAE, fill = model)) +
  geom_col(position = "dodge") +
  facet_wrap(~ dataset, scales = "free_y") +
  labs(x = "Ocasiones en la estimación", y = "MAE en el holdout", fill = NULL,
       title = "Error según cuántas veces compró antes del corte") +
  theme_bw()
ggsave("outputs/figures/17_mae_by_frequency.png", p, width = 8, height = 4.5, dpi = 150)
cat("17 OK\n")
