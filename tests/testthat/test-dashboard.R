# archivo: tests/testthat/test-dashboard.R
source("../../R/dashboard_filter.R")

dt <- data.table(
  Id = c("1", "10", "100"),
  PAlive = c(0.9, 0.2, 0.5),
  predicted.CLV = c(200, 20, 80)
)

test_that("filtra por P(activo), CLV e Id", {
  expect_equal(filter_customers(dt, 0.4, 0, "")$Id, c("1", "100"))
  expect_equal(filter_customers(dt, 0, 50, "")$Id, c("1", "100"))
  expect_equal(filter_customers(dt, 0, 0, "10")$Id, c("10", "100"))
  expect_equal(nrow(filter_customers(dt, 0.99, 0, "")), 0)
})
