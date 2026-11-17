# archivo: R/06_covariates.R
source("R/00_utils.R")
suppressPackageStartupMessages({ library(CLVTools); library(data.table) })
ensure_dirs()

# ATENCIÓN: los covariables de apparel son SIMULADOS. Sirven para aprender la mecánica
# del modelo, no como evidencia de efectos reales.
data("apparelTrans",     package = "CLVTools")
data("apparelStaticCov", package = "CLVTools")
data("apparelDynCov",    package = "CLVTools")

# Nota (comprobada): con estimation.split = 40 el Pareto/NBD base NO converge en apparel
# (coeficientes NA). Con 52, 104 o 156 semanas sí. Usamos 104.
SPLIT_APP <- 104
clv_app <- clvdata(apparelTrans, date.format = "ymd", time.unit = TIME_UNIT,
                   estimation.split = SPLIT_APP,
                   name.id = "Id", name.date = "Date", name.price = "Price")

# --- (a) Sin covariables ----------------------------------------------------------
fit_base <- pnbd(clv_app, verbose = FALSE)

# --- (b) Covariables estáticas (Gender, Channel) en compra y abandono -------------
clv_static <- SetStaticCovariates(clv_app,
  data.cov.life  = apparelStaticCov, names.cov.life  = c("Gender", "Channel"),
  data.cov.trans = apparelStaticCov, names.cov.trans = c("Gender", "Channel"),
  name.id = "Id")
fit_static <- pnbd(clv_static, verbose = FALSE)

# --- (c) Covariables dinámicas (High.Season, Gender, Channel) ---------------------
clv_dyn <- SetDynamicCovariates(clv_app,
  data.cov.life  = apparelDynCov, names.cov.life  = c("High.Season", "Gender", "Channel"),
  data.cov.trans = apparelDynCov, names.cov.trans = c("High.Season", "Gender", "Channel"),
  name.id = "Id", name.date = "Cov.Date")
fit_dyn <- pnbd(clv_dyn, verbose = FALSE)

cands <- list(base = fit_base, static = fit_static, dynamic = fit_dyn)

# --- Ajuste en muestra + error en holdout -----------------------------------------
tx <- as.data.table(apparelTrans)[, Date := as.Date(Date)]
split_date <- min(tx$Date) + SPLIT_APP * 7
actual <- tx[Date > split_date, .(actual = .N), by = Id][, Id := as.character(Id)]

holdout_mae <- function(f) {
  p <- as.data.table(predict(f, predict.spending = FALSE, verbose = FALSE))[, Id := as.character(Id)]
  p <- merge(p, actual, by = "Id", all.x = TRUE)[is.na(actual), actual := 0L]
  mae(p$CET, p$actual)
}

cmp <- rbindlist(lapply(names(cands), function(m) {
  f <- cands[[m]]
  data.table(model = m, logLik = as.numeric(logLik(f)), AIC = AIC(f), BIC = BIC(f),
             holdout_MAE = tryCatch(holdout_mae(f), error = function(e) NA_real_))
}))[order(AIC)]
print(cmp)
fwrite(cmp, "outputs/tables/06_covariates_comparison.csv")

# Test de razón de verosimilitud (anidados, mismos datos)
print(tryCatch(lrtest(fit_static, fit_base), error = function(e) conditionMessage(e)))
cat("06 OK\n")
