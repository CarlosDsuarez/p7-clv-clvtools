# archivo: R/04_spending_clv.R
source("R/00_utils.R")
suppressPackageStartupMessages({ library(CLVTools); library(data.table) })
ensure_dirs()

d    <- load_cdnow_clv()
fits <- readRDS("outputs/models/fits_cdnow.rds")

# --- Modelo de gasto Gamma/Gamma ----------------------------------------------
spend_fit <- gg(d$clv, verbose = FALSE)
print(summary(spend_fit))

# Supuesto clave del Gamma/Gamma: gasto medio independiente de la frecuencia
tx <- copy(d$tx)[, Date := lubridate::ymd(Date)]
split_date <- min(tx$Date) + EST_SPLIT_WEEKS * 7
cust <- tx[Date <= split_date, .(n = .N, mean_spend = mean(Price)), by = Id][n >= 2]
rho <- cor(cust$n, cust$mean_spend, method = "spearman")
cat(sprintf("Spearman(frecuencia, gasto medio) = %.3f  (Gamma/Gamma asume independencia; |rho| alto lo cuestiona)\n", rho))

# --- CLV a nivel cliente (horizonte 52 semanas, descuento 10% anual) ----------
clv_pred <- as.data.table(predict(fits$pnbd, predict.spending = spend_fit,
                                  prediction.end = 52,
                                  continuous.discount.factor = disc_per_unit(),
                                  verbose = FALSE))
print(head(clv_pred))
fwrite(clv_pred, "outputs/tables/04_clv_pnbd_52w.csv")

# --- Sensibilidad -------------------------------------------------------------
# OJO (comprobado al probar el código): predicted.CLV = DERT x gasto medio, con horizonte
# INFINITO. Por eso el CLV total depende de la tasa de descuento pero NO de prediction.end.
# El horizonte solo cambia CET y el gasto esperado del período (predicted.period.spending).
run_pred <- function(h = 52, a = DISCOUNT_ANNUAL)
  predict(fits$pnbd, predict.spending = spend_fit, prediction.end = h,
          continuous.discount.factor = disc_per_unit(a), verbose = FALSE)

sens_discount <- data.table(discount = c(0.05, 0.10, 0.15, 0.20))
sens_discount[, total_CLV := sapply(discount, function(a) sum(run_pred(a = a)$predicted.CLV))]
print(sens_discount)

sens_horizon <- data.table(horizon_weeks = c(13, 26, 52, 104))
sens_horizon[, total_period_spending := sapply(horizon_weeks,
               function(h) sum(run_pred(h = h)$predicted.period.spending))]
print(sens_horizon)

fwrite(sens_discount, "outputs/tables/04_sensitivity_discount.csv")
fwrite(sens_horizon,  "outputs/tables/04_sensitivity_horizon.csv")

# Concentración del valor: % del CLV total en el decil superior
setorder(clv_pred, -predicted.CLV)
top_share <- sum(head(clv_pred$predicted.CLV, ceiling(nrow(clv_pred) * 0.10))) / sum(clv_pred$predicted.CLV)
cat(sprintf("Decil superior concentra %.1f%% del CLV predicho\n", 100 * top_share))
cat("04 OK\n")
