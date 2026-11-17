# archivo: R/01_load_validate.R
source("R/00_utils.R")
suppressPackageStartupMessages(library(CLVTools))
ensure_dirs()

d <- load_cdnow_clv()
print(d$clv)   # clientes, transacciones, ventana de estimación y holdout

# EDA: 4 gráficos estándar sobre los datos de transacciones
for (w in c("tracking", "frequency", "spending", "interpurchasetime")) {
  ggplot2::ggsave(sprintf("outputs/figures/01_%s.png", w),
                  plot(d$clv, which = w), width = 8, height = 4.5, dpi = 150)
}
cat("01 OK: gráficos en outputs/figures/\n")
