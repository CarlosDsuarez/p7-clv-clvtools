# archivo: R/00_utils.R
suppressPackageStartupMessages(library(data.table))

# ---- Parámetros del proyecto (una sola fuente de verdad) --------------------
SEED            <- 42L
TIME_UNIT       <- "week"
UNITS_PER_YEAR  <- 52
DISCOUNT_ANNUAL <- 0.10
EST_SPLIT_WEEKS <- 39

# CLVTools usa una tasa de descuento CONTINUA por unidad de tiempo.
# Con unidad = semana hay que dividir entre 52 (ver ?predict en el manual).
disc_per_unit <- function(annual = DISCOUNT_ANNUAL, units_per_year = UNITS_PER_YEAR) {
  log(1 + annual) / units_per_year
}

# ---- Métricas ---------------------------------------------------------------
mae  <- function(pred, actual) mean(abs(pred - actual))
rmse <- function(pred, actual) sqrt(mean((pred - actual)^2))

# Calibración por deciles de la predicción: promedio predicho vs. observado
decile_calibration <- function(pred, actual, n = 10) {
  dt <- data.table(pred = pred, actual = actual)
  dt[, bin := ceiling(rank(pred, ties.method = "first") / .N * n)]
  dt[, .(mean_pred = mean(pred), mean_actual = mean(actual), n = .N), by = bin][order(bin)]
}

# ---- Validación de datos ----------------------------------------------------
validate_transactions <- function(dt) {
  dt <- as.data.table(dt)
  req <- c("Id", "Date", "Price")
  stopifnot("faltan columnas Id/Date/Price" = all(req %in% names(dt)))
  stopifnot("hay NA en Id/Date/Price" = !anyNA(dt[, ..req]))
  stopifnot("hay precios negativos" = all(dt$Price >= 0))
  invisible(TRUE)
}

ensure_dirs <- function() {
  for (d in c("outputs/figures", "outputs/tables", "outputs/models"))
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# ---- Carga del dataset principal (CDNOW, incluido en CLVTools) --------------
load_cdnow_clv <- function() {
  suppressPackageStartupMessages(library(CLVTools))
  data("cdnow", package = "CLVTools", envir = environment())
  tx <- as.data.table(cdnow)
  validate_transactions(tx)
  clv <- clvdata(tx, date.format = "ymd", time.unit = TIME_UNIT,
                 estimation.split = EST_SPLIT_WEEKS,
                 name.id = "Id", name.date = "Date", name.price = "Price")
  list(tx = tx, clv = clv)
}
