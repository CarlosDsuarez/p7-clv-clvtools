# archivo: tests/testthat/test-metrics.R
source("../../R/00_utils.R")

test_that("mae y rmse calculan lo esperado", {
  expect_equal(mae(c(1, 2, 3), c(1, 3, 5)), 1)
  expect_equal(rmse(c(0, 0), c(3, 4)), sqrt(12.5))
})

test_that("decile_calibration reparte en n bins y respeta el orden", {
  set.seed(1)
  p <- runif(1000); a <- rpois(1000, p)
  cal <- decile_calibration(p, a, n = 10)
  expect_equal(nrow(cal), 10)
  expect_equal(sum(cal$n), 1000)
  expect_true(all(diff(cal$mean_pred) >= 0))
})

test_that("el descuento por unidad es el continuo anual dividido entre las unidades", {
  expect_equal(disc_per_unit(0.10, 52), log(1.10) / 52)
  expect_lt(disc_per_unit(0.10, 52), disc_per_unit(0.10, 1))
})
