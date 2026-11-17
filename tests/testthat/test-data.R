# archivo: tests/testthat/test-data.R
source("../../R/00_utils.R")
source("../../R/features.R")

ok <- data.table(Id = c("a", "a", "b"), Date = as.Date("2020-01-01") + c(0, 7, 3), Price = c(10, 12, 5))

test_that("validate_transactions acepta datos válidos y rechaza inválidos", {
  expect_true(validate_transactions(ok))
  expect_error(validate_transactions(ok[, .(Id, Date)]))
  bad <- copy(ok); bad[1, Price := NA]
  expect_error(validate_transactions(bad))
  neg <- copy(ok); neg[1, Price := -1]
  expect_error(validate_transactions(neg))
})

test_that("features_at NO usa transacciones posteriores a t1 (sin fuga temporal)", {
  tx <- data.table(Id = c("a", "a", "a", "b"), Price = c(10, 10, 999, 5), wk = c(0, 5, 30, 2))
  f <- features_at(tx, t1 = 10)
  expect_equal(f[Id == "a", n], 2)                  # la compra de la semana 30 queda fuera
  expect_equal(f[Id == "a", total_spend], 20)       # el gasto 999 no entra
  y <- target_in(tx, t1 = 10, H = 30)
  expect_equal(y[Id == "a", y], 1)                  # y SÍ cuenta en el objetivo
})
