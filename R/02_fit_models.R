# archivo: R/02_fit_models.R
source("R/00_utils.R")
suppressPackageStartupMessages({ library(CLVTools); library(data.table) })
ensure_dirs(); set.seed(SEED)

d <- load_cdnow_clv()

fit_safe <- function(expr) tryCatch(expr, error = function(e) {
  message("Ajuste fallido: ", conditionMessage(e)); NULL })

fits <- list(
  pnbd    = fit_safe(pnbd(d$clv,    verbose = FALSE)),
  bgnbd   = fit_safe(bgnbd(d$clv,   verbose = FALSE)),
  ggomnbd = fit_safe(ggomnbd(d$clv, verbose = FALSE))
)
fits <- Filter(Negate(is.null), fits)

comparison <- rbindlist(lapply(names(fits), function(m) {
  f <- fits[[m]]
  data.table(model = m, logLik = as.numeric(logLik(f)),
             AIC = AIC(f), BIC = BIC(f), n_customers = nobs(f))
}))[order(AIC)]
print(comparison)

fwrite(comparison, "outputs/tables/02_model_comparison.csv")
saveRDS(fits, "outputs/models/fits_cdnow.rds")
cat("02 OK\n")
