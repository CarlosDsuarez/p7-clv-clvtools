# Tramos de frecuencia en la ventana de estimación.
# n es el número de ocasiones, incluida la primera.
suppressPackageStartupMessages(library(data.table))

frequency_bin <- function(n) {
  fcase(
    n <= 1, "1",
    n == 2, "2",
    n <= 5, "3-5",
    default = "6+"
  )
}
