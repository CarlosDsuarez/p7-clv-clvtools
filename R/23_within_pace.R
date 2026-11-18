# archivo: R/23_within_pace.R
# Hipótesis fijada antes de mirar el intervalo:
# en la mitad alta, entre quienes compran al menos dos veces en el
# holdout, la mediana de (intervalo de la segunda mitad de la estimación
# − intervalo de la primera mitad) es menor o igual que cero.
# Cada mitad usa la misma cantidad de intervalos entre compras. Si el
# número de intervalos es impar, el del centro no entra.
# El ritmo se mide antes del corte. El grupo es el de R/22_purchase_pace.R.
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
  hold <- tx[Date > split_date, .(actual = .N), by = Id]
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
  est
}

slice_rows <- function(dataset, cell, slice, x) {
  ok <- nrow(x) > 0 && !anyNA(x$early_gap)
  data.table(
    dataset = dataset, cell = cell, slice = slice,
    n_customers = nrow(x),
    mean_actual = if (nrow(x)) mean(x$actual) else NA_real_,
    mean_calendar = if (nrow(x)) mean(x$naive_calendar) else NA_real_,
    median_early = if (ok) median(x$early_gap) else NA_real_,
    median_late = if (ok) median(x$late_gap) else NA_real_,
    median_diff = if (ok) median(x$late_gap - x$early_gap) else NA_real_,
    mean_early = if (ok) mean(x$early_gap) else NA_real_,
    mean_late = if (ok) mean(x$late_gap) else NA_real_,
    share_slower = if (ok) mean(x$late_gap > x$early_gap) else NA_real_
  )
}

score_half <- function(dataset, cell, x) {
  rbind(
    slice_rows(dataset, cell, "half", x),
    slice_rows(dataset, cell, "pace", x[actual >= 2])
  )
}

score_dataset <- function(dataset, tx) {
  d <- customer_table(tx)
  recent <- d[bin == "6+" & recency == "recent"]
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
out[, slice := factor(slice, levels = c("half", "pace"))]
setorder(out, dataset, cell, slice)
print(out)
fwrite(out, "outputs/tables/23_within_pace.csv")

pace <- out[slice == "pace" & cell != "recent_all"]
long <- melt(
  pace,
  id.vars = c("dataset", "cell"),
  measure.vars = c("median_early", "median_late"),
  variable.name = "which",
  value.name = "weeks"
)
long[, which := fifelse(which == "median_early", "primera mitad", "segunda mitad")]
p <- ggplot(long, aes(cell, weeks, fill = which)) +
  geom_col(position = "dodge") +
  facet_wrap(~ dataset) +
  labs(x = NULL, y = "Mediana de semanas entre compras", fill = NULL,
       title = "Ritmo dentro de la estimación, antes del corte") +
  theme_bw()
ggsave("outputs/figures/23_within_pace.png", p, width = 8, height = 4.5, dpi = 150)
cat("23 OK\n")
