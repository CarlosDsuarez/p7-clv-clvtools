# archivo: R/run_all.R
# Ejecuta el pipeline completo desde una clonación limpia:
#   renv::restore(); Rscript R/run_all.R
scripts <- c("R/01_load_validate.R", "R/02_fit_models.R", "R/03_holdout_validation.R",
             "R/04_spending_clv.R", "R/05_benchmark_xgboost.R",
             "R/06_covariates.R", "R/07_simulation_recovery.R")
for (s in scripts) {
  cat("\n=====", s, "=====\n")
  t0 <- Sys.time()
  source(s, local = new.env())
  cat(sprintf("(%.1f s)\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
