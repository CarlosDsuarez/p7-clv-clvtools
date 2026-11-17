# Comercios sintéticos que originan BNPL. El proceso es el Pareto/NBD de simulate.R.
# Id es el comercio, Date el día con originación y Price el monto de esa ocasión.
# No es una cartera real y no representa impago.
simulate_bnpl_merchants <- function(n = 2000, r = 0.553, alpha = 10.578,
                                    s = 0.606, beta = 11.669,
                                    t_end = 78, first_max = 12, seed = 42L) {
  tx <- simulate_pnbd(n = n, r = r, alpha = alpha, s = s, beta = beta,
                      t_end = t_end, first_max = first_max, seed = seed)
  list(
    tx = tx,
    truth = list(r = r, alpha = alpha, s = s, beta = beta),
    n = n,
    t_end = t_end,
    first_max = first_max,
    seed = seed
  )
}
