# Filtra la tabla de CLV por cliente. La usa shiny/app.R.
suppressPackageStartupMessages(library(data.table))

filter_customers <- function(dt, palive_min, clv_min, id_query) {
  stopifnot(all(c("Id", "PAlive", "predicted.CLV") %in% names(dt)))
  x <- dt[PAlive >= palive_min & predicted.CLV >= clv_min]
  q <- trimws(id_query)
  if (nzchar(q)) x <- x[grepl(q, Id, fixed = TRUE)]
  x[]
}
