# archivo: R/simulate.R
suppressPackageStartupMessages(library(data.table))

# Simula transacciones de un proceso Pareto/NBD con parámetros conocidos.
# Valores por defecto ilustrativos (orden de magnitud de CDNOW).
simulate_pnbd <- function(n = 3000, r = 0.553, alpha = 10.578, s = 0.606, beta = 11.669,
                          t_end = 78, first_max = 12, origin = as.Date("2000-01-03"),
                          seed = 42L) {
  set.seed(seed)
  lambda <- rgamma(n, shape = r, rate = alpha)   # tasa de compra mientras está "vivo"
  mu     <- rgamma(n, shape = s, rate = beta)    # tasa de abandono
  first  <- runif(n, 0, first_max)               # semana de la primera compra
  tau    <- rexp(n, rate = mu)                   # vida del cliente
  end_i  <- pmin(first + tau, t_end)
  n_rep  <- rpois(n, lambda * (end_i - first))   # compras repetidas
  rows <- lapply(seq_len(n), function(i) {
    t <- c(first[i], first[i] + sort(runif(n_rep[i], 0, end_i[i] - first[i])))
    data.table(Id = i, wk = t)
  })
  tx <- rbindlist(rows)
  tx[, Date := origin + round(wk * 7)]
  tx[, Price := round(rgamma(.N, shape = 2, rate = 0.1), 2)]
  tx[, .(Id = as.character(Id), Date, Price)]
}
