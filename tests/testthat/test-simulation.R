# archivo: tests/testthat/test-simulation.R
source("../../R/00_utils.R")
source("../../R/simulate.R")

test_that("simulate_pnbd es reproducible y respeta el formato esperado", {
  a <- simulate_pnbd(n = 200, seed = 7)
  b <- simulate_pnbd(n = 200, seed = 7)
  expect_identical(a, b)
  expect_true(all(c("Id", "Date", "Price") %in% names(a)))
  expect_true(validate_transactions(a))
  expect_equal(uniqueN(a$Id) <= 200, TRUE)
})

test_that("la primera compra de cada cliente existe y no hay fechas fuera de la ventana", {
  a <- simulate_pnbd(n = 300, t_end = 78, seed = 3)
  expect_lte(as.numeric(max(a$Date) - as.Date("2000-01-03")) / 7, 78.5)
  expect_equal(uniqueN(a$Id), 300)
})
