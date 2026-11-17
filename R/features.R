# archivo: R/features.R
suppressPackageStartupMessages(library(data.table))

# Características RFM por cliente usando SOLO transacciones con wk <= t1.
# `tx` debe tener: Id, Price, wk (semanas desde la primera fecha del dataset).
features_at <- function(tx, t1) {
  w <- tx[wk <= t1]
  f <- w[, .(first_wk = min(wk), last_wk = max(wk), n = .N,
             mean_spend = mean(Price), total_spend = sum(Price)), by = Id]
  f[, `:=`(x = n - 1, T_age = pmax(t1 - first_wk, 1e-6), t_x = last_wk - first_wk)]
  # Variables sin escala (tasas y ratios) para que ventanas de distinto largo sean comparables
  f[, `:=`(rate_x = x / T_age, rec_ratio = t_x / T_age, spend_rate = total_spend / T_age)]
  f[]
}

# Variable objetivo: nº de transacciones en (t1, t1 + H]
target_in <- function(tx, t1, H) {
  tx[wk > t1 & wk <= t1 + H, .(y = .N), by = Id]
}

make_set <- function(tx, t1, H) {
  s <- merge(features_at(tx, t1), target_in(tx, t1, H), by = "Id", all.x = TRUE)
  s[is.na(y), y := 0L]
  s[, y_rate := y / H]
  s[]
}

FEATURE_COLS <- c("rate_x", "rec_ratio", "mean_spend", "spend_rate")
