# archivo: tests/testthat/test-frequency-bins.R
source("../../R/frequency_bins.R")

test_that("los cortes de frecuencia quedan en 1, 2, 3-5 y 6+", {
  expect_equal(frequency_bin(c(1, 2, 3, 5, 6, 12)), c("1", "2", "3-5", "3-5", "6+", "6+"))
})
