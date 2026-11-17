# archivo: tests/testthat/test-rank-metrics.R
source("../../R/rank_metrics.R")

test_that("el decil superior se queda con las compras que el orden predice", {
  pred <- c(1, 5, 2, 9, 3, 8, 4, 7, 6, 0)
  actual <- c(0, 0, 0, 10, 0, 0, 0, 0, 0, 0)
  expect_equal(top_decile_capture(pred, actual), 1)
  expect_equal(safe_spearman(pred, pred), 1)
})

test_that("sin compras observadas la concentración no se define", {
  expect_true(is.na(top_decile_capture(c(1, 2, 3), c(0, 0, 0))))
})
