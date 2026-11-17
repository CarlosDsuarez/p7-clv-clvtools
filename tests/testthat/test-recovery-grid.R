# archivo: tests/testthat/test-recovery-grid.R
source("../../R/recovery_grid.R")

test_that("el resumen ignora ajustes fallidos y agrupa por n y parámetro", {
  detail <- data.table(
    n = c(100, 100, 100, 500),
    seed = c(1, 2, 3, 1),
    param = c("E[mu]", "E[mu]", "E[mu]", "E[mu]"),
    rel_error = c(0.2, -0.1, NA, 0.4)
  )
  out <- summarize_recovery(detail)
  expect_equal(nrow(out), 2)
  expect_equal(out[n == 100, n_ok], 2)
  expect_equal(out[n == 100, mean_rel_error], 0.05)
  expect_equal(out[n == 500, median_abs_rel_error], 0.4)
})
