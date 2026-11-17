# archivo: R/09_uncertainty.R
# Intervalos bootstrap al 90% para el CET del holdout y para el CLV.
# El default de predict() es num.boots = 100, pero CLVTools avisa que
# recomienda 1000 o más. Se usan 1000. No se cambia EST_SPLIT_WEEKS.
source("R/00_utils.R")
suppressPackageStartupMessages({
  library(CLVTools)
  library(data.table)
  library(ggplot2)
})
ensure_dirs()

NUM_BOOTS <- 1000L
LEVEL <- 0.9

d <- load_cdnow_clv()
fit <- pnbd(d$clv, verbose = FALSE)
spend <- gg(d$clv, verbose = FALSE)

set.seed(SEED)
cet <- as.data.table(predict(fit, predict.spending = FALSE,
                             uncertainty = "boots", level = LEVEL,
                             num.boots = NUM_BOOTS, verbose = FALSE))
cet[, Id := as.character(Id)]
stopifnot(all(c("CET", "CET.CI.5", "CET.CI.95") %in% names(cet)))

tx <- copy(d$tx)[, Date := lubridate::ymd(Date)]
tx[, Id := as.character(Id)]
origin <- min(tx$Date)
split_date <- origin + EST_SPLIT_WEEKS * 7
actual <- tx[Date > split_date, .(actual = .N), by = Id]
cet <- merge(cet, actual, by = "Id", all.x = TRUE)
cet[is.na(actual), actual := 0L]

cet[, width := CET.CI.95 - CET.CI.5]
cet[, covered := actual >= CET.CI.5 & actual <= CET.CI.95]
cet[, point_in := CET >= CET.CI.5 & CET <= CET.CI.95]
cet[, bin := ceiling(rank(CET, ties.method = "first") / .N * 10)]

by_decile <- cet[, .(
  n = .N,
  mean_cet = mean(CET),
  mean_actual = mean(actual),
  median_width = median(width),
  coverage = mean(covered)
), by = bin][order(bin)]

cet_summary <- data.table(
  n_customers = nrow(cet),
  num_boots = NUM_BOOTS,
  level = LEVEL,
  coverage_of_counts = mean(cet$covered),
  pct_point_inside = mean(cet$point_in),
  median_width = median(cet$width),
  median_rel_width = median(cet$width / pmax(cet$CET, 1e-8))
)

set.seed(SEED)
clv <- as.data.table(predict(fit, predict.spending = spend,
                             prediction.end = 52,
                             continuous.discount.factor = disc_per_unit(),
                             uncertainty = "boots", level = LEVEL,
                             num.boots = NUM_BOOTS, verbose = FALSE))
clv[, Id := as.character(Id)]
stopifnot(all(c("predicted.CLV", "predicted.CLV.CI.5", "predicted.CLV.CI.95") %in% names(clv)))
clv[, width := predicted.CLV.CI.95 - predicted.CLV.CI.5]
clv[, point_in := predicted.CLV >= predicted.CLV.CI.5 &
      predicted.CLV <= predicted.CLV.CI.95]

clv_summary <- data.table(
  n_customers = nrow(clv),
  num_boots = NUM_BOOTS,
  level = LEVEL,
  sum_clv = sum(clv$predicted.CLV),
  sum_ci_low = sum(clv$predicted.CLV.CI.5),
  sum_ci_high = sum(clv$predicted.CLV.CI.95),
  median_width = median(clv$width),
  median_rel_width = median(clv$width / pmax(clv$predicted.CLV, 1e-8)),
  pct_point_inside = mean(clv$point_in)
)

print(cet_summary)
print(by_decile)
print(clv_summary)

fwrite(cet[, .(Id, CET, CET.CI.5, CET.CI.95, actual)],
       "outputs/tables/09_cet_intervals.csv")
fwrite(cet_summary, "outputs/tables/09_cet_uncertainty_summary.csv")
fwrite(by_decile, "outputs/tables/09_cet_coverage_by_decile.csv")
fwrite(clv[, .(Id, predicted.CLV, predicted.CLV.CI.5, predicted.CLV.CI.95)],
       "outputs/tables/09_clv_intervals.csv")
fwrite(clv_summary, "outputs/tables/09_clv_uncertainty_summary.csv")

p <- ggplot(by_decile, aes(factor(bin), coverage)) +
  geom_col(fill = "gray35") +
  geom_hline(yintercept = LEVEL, linetype = 2) +
  scale_y_continuous(limits = c(0, 1), labels = function(x) paste0(round(100 * x), "%")) +
  labs(x = "Decil de CET",
       y = "Conteos del holdout dentro del intervalo") +
  theme_bw()
ggsave("outputs/figures/09_cet_coverage_deciles.png", p, width = 8, height = 4.5, dpi = 150)
cat("09 OK\n")
