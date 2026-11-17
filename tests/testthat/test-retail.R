# archivo: tests/testthat/test-retail.R
source("../../R/retail_prepare.R")

raw <- data.table(
  Invoice = c("1", "1", "C2", "3", "4", "5"),
  Quantity = c(2, 1, 1, -1, 1, 4),
  InvoiceDate = as.POSIXct(c(
    "2009-12-01 08:00:00", "2009-12-01 08:00:00", "2009-12-02 08:00:00",
    "2009-12-03 08:00:00", "2010-06-01 08:00:00", "2011-12-01 08:00:00"
  ), tz = "UTC"),
  Price = c(5, 3, 4, 2, 10, 7),
  `Customer ID` = c(10, 10, 10, 10, 20, 10)
)

test_that("suma el día, tira devoluciones y recorta la cohorte", {
  out <- prepare_retail_transactions(raw, first_weeks = 13, split_weeks = 39, horizon_weeks = 39)
  expect_equal(out$n_identified, 2)
  expect_equal(out$n_cohort, 1)
  expect_equal(nrow(out$tx), 1)
  expect_equal(out$tx$Id, "10")
  expect_equal(out$tx$Price, 13)
  expect_equal(out$tx$Date, as.Date("2009-12-01"))
})

test_that("cuenta ocasiones dentro de una ventana semiabierta", {
  tx <- data.table(
    Id = c("a", "a", "b"),
    Date = as.Date(c("2010-12-01", "2010-12-20", "2010-12-29")),
    Price = c(1, 1, 1)
  )
  got <- count_between(tx, as.Date("2010-12-01"), as.Date("2010-12-29"))
  expect_equal(got[Id == "a", y], 2)
  expect_equal(nrow(got[Id == "b"]), 0)
})
