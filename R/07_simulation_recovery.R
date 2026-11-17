# archivo: R/07_simulation_recovery.R
source("R/00_utils.R"); source("R/simulate.R")
suppressPackageStartupMessages({ library(CLVTools); library(data.table) })
ensure_dirs()

truth <- list(r = 0.553, alpha = 10.578, s = 0.606, beta = 11.669)
tx <- simulate_pnbd(n = 3000, r = truth$r, alpha = truth$alpha, s = truth$s, beta = truth$beta)
validate_transactions(tx)

clv <- clvdata(tx, date.format = "ymd", time.unit = TIME_UNIT, estimation.split = EST_SPLIT_WEEKS,
               name.id = "Id", name.date = "Date", name.price = "Price")
fit <- pnbd(clv, verbose = FALSE)
est <- coef(fit)

out <- data.table(param = c("r", "alpha", "s", "beta", "E[lambda]=r/alpha", "E[mu]=s/beta"),
                  truth = c(truth$r, truth$alpha, truth$s, truth$beta,
                            truth$r / truth$alpha, truth$s / truth$beta),
                  estimate = c(est[["r"]], est[["alpha"]], est[["s"]], est[["beta"]],
                               est[["r"]] / est[["alpha"]], est[["s"]] / est[["beta"]]))
out[, rel_error := (estimate - truth) / truth]
print(out)
fwrite(out, "outputs/tables/07_parameter_recovery.csv")
cat("07 OK: los parámetros individuales (alpha, beta) están débilmente identificados;\n",
    "   las medias implícitas E[lambda], E[mu] son la comparación fiable.\n")
