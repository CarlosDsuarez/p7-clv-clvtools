# Pipeline con targets. No reescribe los modelos: cada paso corre el script
# que ya existe y la caché evita repetirlo si el script y sus entradas no cambian.
# run_all.R sigue siendo el camino de la especificación, sin esta capa.
library(targets)

tar_option_set(error = "stop")

run_script <- function(path) {
  source(path, local = new.env(parent = globalenv()))
  invisible(path)
}

list(
  tar_target(utils_r, "R/00_utils.R", format = "file"),
  tar_target(features_r, "R/features.R", format = "file"),
  tar_target(simulate_r, "R/simulate.R", format = "file"),
  tar_target(script_01, "R/01_load_validate.R", format = "file"),
  tar_target(script_02, "R/02_fit_models.R", format = "file"),
  tar_target(script_03, "R/03_holdout_validation.R", format = "file"),
  tar_target(script_04, "R/04_spending_clv.R", format = "file"),
  tar_target(script_05, "R/05_benchmark_xgboost.R", format = "file"),
  tar_target(script_06, "R/06_covariates.R", format = "file"),
  tar_target(script_07, "R/07_simulation_recovery.R", format = "file"),
  tar_target(script_08, "R/08_rolling_origin.R", format = "file"),
  tar_target(script_09, "R/09_uncertainty.R", format = "file"),

  tar_target(step_01, {
    utils_r
    run_script(script_01)
    c("outputs/figures/01_tracking.png",
      "outputs/figures/01_frequency.png",
      "outputs/figures/01_spending.png",
      "outputs/figures/01_interpurchasetime.png")
  }, format = "file"),

  tar_target(step_02, {
    utils_r
    run_script(script_02)
    c("outputs/tables/02_model_comparison.csv",
      "outputs/models/fits_cdnow.rds")
  }, format = "file"),

  tar_target(step_03, {
    step_02
    run_script(script_03)
    c("outputs/tables/03_holdout_metrics.csv",
      "outputs/tables/03_calibration_pnbd_deciles.csv",
      "outputs/models/holdout_preds.rds",
      "outputs/figures/03_tracking_pnbd.png")
  }, format = "file"),

  tar_target(step_04, {
    step_02
    run_script(script_04)
    c("outputs/tables/04_clv_pnbd_52w.csv",
      "outputs/tables/04_sensitivity_discount.csv",
      "outputs/tables/04_sensitivity_horizon.csv")
  }, format = "file"),

  tar_target(step_05, {
    features_r
    step_03
    run_script(script_05)
    "outputs/tables/05_benchmark.csv"
  }, format = "file"),

  tar_target(step_06, {
    utils_r
    run_script(script_06)
    "outputs/tables/06_covariates_comparison.csv"
  }, format = "file"),

  tar_target(step_07, {
    utils_r
    simulate_r
    run_script(script_07)
    "outputs/tables/07_parameter_recovery.csv"
  }, format = "file"),

  tar_target(step_08, {
    utils_r
    run_script(script_08)
    c("outputs/tables/08_rolling_origin.csv",
      "outputs/tables/08_rolling_origin_summary.csv",
      "outputs/figures/08_rolling_mae.png")
  }, format = "file"),

  tar_target(step_09, {
    utils_r
    run_script(script_09)
    c("outputs/tables/09_cet_intervals.csv",
      "outputs/tables/09_cet_uncertainty_summary.csv",
      "outputs/tables/09_cet_coverage_by_decile.csv",
      "outputs/tables/09_clv_intervals.csv",
      "outputs/tables/09_clv_uncertainty_summary.csv",
      "outputs/figures/09_cet_coverage_deciles.png")
  }, format = "file")
)
