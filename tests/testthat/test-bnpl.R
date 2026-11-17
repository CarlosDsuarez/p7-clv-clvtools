# archivo: tests/testthat/test-bnpl.R
source("../../R/00_utils.R")
source("../../R/simulate.R")
source("../../R/bnpl_merchants.R")

test_that("los comercios sintéticos son reproducibles y traen los parámetros", {
  a <- simulate_bnpl_merchants(n = 80, seed = 3)
  b <- simulate_bnpl_merchants(n = 80, seed = 3)
  expect_identical(a$tx, b$tx)
  expect_true(validate_transactions(a$tx))
  expect_equal(uniqueN(a$tx$Id), 80)
  expect_equal(a$truth$r, 0.553)
  expect_equal(a$seed, 3)
})
