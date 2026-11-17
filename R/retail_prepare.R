# Arma ocasiones de compra para Online Retail II.
# Una ocasión es un cliente-día. El valor es la suma de Quantity * Price.
suppressPackageStartupMessages(library(data.table))

prepare_retail_transactions <- function(raw, first_weeks = 13, split_weeks = 39,
                                        horizon_weeks = 39) {
  dt <- as.data.table(raw)
  if ("Customer ID" %in% names(dt)) setnames(dt, "Customer ID", "CustomerID")
  need <- c("Invoice", "Quantity", "InvoiceDate", "Price", "CustomerID")
  stopifnot("faltan columnas de Online Retail" = all(need %in% names(dt)))
  n_input <- nrow(dt)
  n_missing_id <- sum(is.na(dt$CustomerID))

  dt <- dt[!is.na(CustomerID) & Quantity > 0 & Price > 0]
  dt <- dt[!grepl("^C", as.character(Invoice))]
  dt[, Id := as.character(CustomerID)]
  dt[, Date := as.Date(InvoiceDate)]
  dt[, line_value := Quantity * Price]
  n_invoices <- uniqueN(dt[, .(Id, Invoice)])
  tx <- dt[, .(Price = sum(line_value)), by = .(Id, Date)]
  tx <- tx[Price > 0]

  origin <- min(tx$Date)
  first <- tx[, .(first = min(Date)), by = Id]
  first[, wk := as.numeric(difftime(first, origin, units = "weeks"))]
  keep <- first[wk < first_weeks, Id]
  end_date <- origin + (split_weeks + horizon_weeks) * 7
  tx <- tx[Id %in% keep & Date <= end_date]

  list(
    tx = tx[, .(Id, Date, Price)],
    origin = origin,
    end_date = end_date,
    n_input = n_input,
    n_missing_id = n_missing_id,
    n_invoices = n_invoices,
    n_identified = uniqueN(first$Id),
    n_cohort = uniqueN(keep)
  )
}
