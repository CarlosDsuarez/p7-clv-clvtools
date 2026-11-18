# archivo: R/24_pace_continuation.R
# Hipótesis fijada antes de mirar la diferencia:
# en la mitad alta, entre quienes compran al menos dos veces en el
# holdout, la mediana de (intervalo del holdout − intervalo de la
# segunda mitad de la estimación) es menor o igual que cero.
# El intervalo del holdout es el de R/22_purchase_pace.R. El de la
# segunda mitad es el de R/23_within_pace.R. El grupo es el mismo.
# Si se cumple, el frenazo de la estimación no sigue después del corte.
source("R/00_utils.R")
source("R/retail_prepare.R")
source("R/frequency_bins.R")
suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(readxl)
})
ensure_dirs()
set.seed(SEED)

interval_halves <- function(dates) {
  dates <- sort(as.Date(dates))
  if (length(dates) < 2) {
    return(data.table(early_gap = NA_real_, late_gap = NA_real_))
  }
  d <- as.numeric(difftime(dates[-1], dates[-length(dates)], units = "weeks"))
  h <- floor(length(d) / 2)
  if (h < 1) {
    return(data.table(early_gap = NA_real_, late_gap = NA_real_))
  }
  data.table(
    early_gap = mean(d[seq_len(h)]),
    late_gap = mean(d[seq.int(length(d) - h + 1L, length(d))])
  )
}

customer_table <- function(tx) {
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
  est_tx <- tx[Date <= split_date]
  est <- est_tx[, .(
    n = .N,
    first_wk = as.numeric(difftime(min(Date), origin, units = "weeks")),
    last_wk = as.numeric(difftime(max(Date), origin, units = "weeks"))
  ), by = Id]
  gaps <- est_tx[, interval_halves(Date), by = Id]
  est <- merge(est, gaps, by = "Id")
  est[, age := pmax(EST_SPLIT_WEEKS - first_wk, 1e-6)]
  est[, rate := (n - 1) / age]
  est[, naive_calendar := (n - 1) / EST_SPLIT_WEEKS * H]
  est[, bin := frequency_bin(n)]
  est[, recency := fifelse(last_wk < EST_SPLIT_WEEKS / 2, "silent", "recent")]
  est <- merge(est, hold, by = "Id", all.x = TRUE)
  est[is.na(actual), actual := 0]
  est[, first_h := as.Date(first_h)]
  est[, last_h := as.Date(last_h)]
  est[, span := pmax(as.numeric(difftime(last_h, first_h, units = "weeks")), 1 / 7)]
  est[, hold_gap := NA_real_]
  est[actual >= 2, hold_gap := span / (actual - 1)]
  est
}

slice_rows <- function(dataset, cell, x) {
  ok <- nrow(x) > 0 && !anyNA(x$late_gap) && !anyNA(x$hold_gap)
  data.table(
    dataset = dataset, cell = cell,
    n_customers = nrow(x),
    mean_actual = if (nrow(x)) mean(x$actual) else NA_real_,
    mean_calendar = if (nrow(x)) mean(x$naive_calendar) else NA_real_,
    median_late = if (ok) median(x$late_gap) else NA_real_,
    median_hold = if (ok) median(x$hold_gap) else NA_real_,
    median_diff = if (ok) median(x$hold_gap - x$late_gap) else NA_real_,
    mean_late = if (ok) mean(x$late_gap) else NA_real_,
    mean_hold = if (ok) mean(x$hold_gap) else NA_real_,
    share_slower = if (ok) mean(x$hold_gap > x$late_gap) else NA_real_
  )
}

score_dataset <- function(dataset, tx) {
  d <- customer_table(tx)
  recent <- d[bin == "6+" & recency == "recent" & actual >= 2]
  cut <- median(d[bin == "6+" & recency == "recent", rate])
  recent[, half := fifelse(rate >= cut, "recent_high", "recent_low")]
  rbind(
    slice_rows(dataset, "recent_low", recent[half == "recent_low"]),
    slice_rows(dataset, "recent_high", recent[half == "recent_high"]),
    slice_rows(dataset, "recent_all", recent)
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
setorder(out, dataset, cell)
print(out)
fwrite(out, "outputs/tables/24_pace_continuation.csv")

long <- melt(
  out[cell != "recent_all"],
  id.vars = c("dataset", "cell"),
  measure.vars = c("median_late", "median_hold"),
  variable.name = "which",
  value.name = "weeks"
)
long[, which := fifelse(which == "median_late", "segunda mitad", "holdout")]
p <- ggplot(long, aes(cell, weeks, fill = which)) +
  geom_col(position = "dodge") +
  facet_wrap(~ dataset) +
  labs(x = NULL, y = "Mediana de semanas entre compras", fill = NULL,
       title = "Ritmo al final de la estimación y en el holdout") +
  theme_bw()
ggsave("outputs/figures/24_pace_continuation.png", p, width = 8, height = 4.5, dpi = 150)
cat("24 OK\n")
