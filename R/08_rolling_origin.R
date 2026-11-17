# archivo: R/08_rolling_origin.R
# Ventanas móviles: mismo horizonte en varios cortes de estimación.
# No cambia EST_SPLIT_WEEKS. El corte de 39 semanas del pipeline principal
# es uno de los orígenes, pero el horizonte aquí es de 13 semanas para que
# el MAE sea comparable entre cortes.
source("R/00_utils.R")
suppressPackageStartupMessages({
  library(CLVTools)
  library(data.table)
  library(ggplot2)
})
ensure_dirs()
set.seed(SEED)

H_ROLL <- 13
SPLITS <- c(26L, 39L, 52L, 64L)

d  <- load_cdnow_clv()
tx <- copy(d$tx)[, Date := lubridate::ymd(Date)]
tx[, Id := as.character(Id)]
origin <- min(tx$Date)
end_wk <- as.numeric(difftime(max(tx$Date), origin, units = "weeks"))
stopifnot("un corte no deja 13 semanas de holdout" =
            all(SPLITS + H_ROLL <= end_wk + 1e-8))

fit_safe <- function(expr) tryCatch(expr, error = function(e) {
  message("Ajuste fallido: ", conditionMessage(e)); NULL })

score_origin <- function(split_weeks) {
  split_date  <- origin + split_weeks * 7
  horizon_end <- split_date + H_ROLL * 7
  clv <- clvdata(tx, date.format = "ymd", time.unit = TIME_UNIT,
                 estimation.split = split_weeks,
                 name.id = "Id", name.date = "Date", name.price = "Price")
  fits <- list(
    pnbd    = fit_safe(pnbd(clv,    verbose = FALSE)),
    bgnbd   = fit_safe(bgnbd(clv,   verbose = FALSE)),
    ggomnbd = fit_safe(ggomnbd(clv, verbose = FALSE))
  )

  actual <- tx[Date > split_date & Date <= horizon_end, .(actual = .N), by = Id]
  est <- tx[Date <= split_date,
            .(n = .N,
              first_wk = as.numeric(difftime(min(Date), origin, units = "weeks"))),
            by = Id]
  est[, naive := (n - 1) / pmax(split_weeks - first_wk, 1e-6) * H_ROLL]

  rows <- list()
  for (m in names(fits)) {
    f <- fits[[m]]
    if (is.null(f)) next
    p <- tryCatch(
      as.data.table(predict(f, predict.spending = FALSE,
                            prediction.end = H_ROLL, verbose = FALSE)),
      error = function(e) {
        message("Predicción fallida (", m, ", corte ", split_weeks, "): ",
                conditionMessage(e))
        NULL
      })
    if (is.null(p)) next
    p[, Id := as.character(Id)]
    p <- merge(p, actual, by = "Id", all.x = TRUE)[is.na(actual), actual := 0L]
    rows[[m]] <- data.table(
      split_weeks = split_weeks, model = m,
      MAE = mae(p$CET, p$actual), RMSE = rmse(p$CET, p$actual),
      bias = mean(p$CET) - mean(p$actual), n_customers = nrow(p))
  }

  nv <- merge(est, actual, by = "Id", all.x = TRUE)[is.na(actual), actual := 0L]
  rows[["naive_rate"]] <- data.table(
    split_weeks = split_weeks, model = "naive_rate",
    MAE = mae(nv$naive, nv$actual), RMSE = rmse(nv$naive, nv$actual),
    bias = mean(nv$naive) - mean(nv$actual), n_customers = nrow(nv))
  rbindlist(rows)
}

detail <- rbindlist(lapply(SPLITS, score_origin))
summary_dt <- detail[, .(
  n_origins = .N,
  MAE_mean = mean(MAE),
  MAE_sd = sd(MAE),
  RMSE_mean = mean(RMSE),
  bias_mean = mean(bias)
), by = model][order(MAE_mean)]

print(detail)
print(summary_dt)
fwrite(detail, "outputs/tables/08_rolling_origin.csv")
fwrite(summary_dt, "outputs/tables/08_rolling_origin_summary.csv")

p <- ggplot(detail, aes(split_weeks, MAE, color = model)) +
  geom_line() +
  geom_point() +
  labs(x = "Semanas de estimación", y = "MAE en las 13 semanas siguientes", color = NULL) +
  theme_bw()
ggsave("outputs/figures/08_rolling_mae.png", p, width = 8, height = 4.5, dpi = 150)
cat("08 OK\n")
