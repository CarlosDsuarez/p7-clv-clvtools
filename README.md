# P7 · Customer Lifetime Value con CLVTools

En un negocio sin contrato el abandono no se observa: solo se ve que el cliente dejó de comprar. Este proyecto estima, para cada cliente de CDNOW, cuántas compras hará en el holdout, si sigue activo y cuánto vale. Compara Pareto/NBD, BG/NBD y GGom/NBD contra un baseline ingenuo y contra un XGBoost con el mismo corte temporal. No es un tutorial: el criterio es el error fuera de tiempo, y el informe dice dónde el modelo falla.

El reporte renderizado está en [`reports/p7_clv.html`](reports/p7_clv.html). Las cifras de abajo salen de `outputs/tables/` de esta corrida (R 4.6.0, CLVTools 0.12.1, xgboost 3.2.1.1).

## Cómo correrlo

Hace falta R ≥ 4.3. CLVTools es GPL-3; si se compila desde fuente hace falta GNU GSL. En macOS arm64 esta corrida usó binarios de CRAN.

```bash
Rscript -e 'renv::restore()'
Rscript R/run_all.R
Rscript R/08_rolling_origin.R
Rscript R/09_uncertainty.R
Rscript R/10_online_retail.R
Rscript R/11_bnpl_merchants.R
Rscript R/12_recovery_by_n.R
Rscript R/13_identification.R
Rscript R/14_seasonality.R
Rscript -e 'targets::tar_make()'
Rscript -e 'shiny::runApp("shiny", launch.browser = TRUE)'
Rscript -e 'testthat::test_dir("tests/testthat", stop_on_failure = TRUE)'
quarto render reports/p7_clv.qmd
```

Los parámetros viven en `R/00_utils.R` (semilla 42, unidad semanal, descuento anual 10%, corte a las 39 semanas). Un cambio se anota en `docs/decisiones.md`. `outputs/models/` no se versiona: `run_all.R` lo regenera.

`targets::tar_make()` corre los mismos scripts y guarda la caché en `_targets/`, que no se sube a git. La primera vez tarda lo mismo que el pipeline; la siguiente, si nada cambió, no reajusta. `run_all.R` sigue siendo el camino sin esa capa.

`shiny::runApp("shiny")` abre el CLV por cliente. No reajusta: lee `04_clv_pnbd_52w.csv` y los intervalos de `09_clv_intervals.csv`. Filtra por P(activo), CLV mínimo e Id.

Online Retail II no está en el repositorio. El script `R/10_online_retail.R` espera `data/raw/online_retail_II.xlsx` (UCI). La cohorte son las primeras 13 semanas desde el 2009-12-01, con el mismo corte de 39 semanas. En ese corte el BG/NBD casi empata al baseline (MAE 2.026 frente a 2.041). En CDNOW la ventaja era de cerca de un 26%.

`R/11_bnpl_merchants.R` genera 2,000 comercios sintéticos. No es el archivo de P13 ni un modelo de impago. `PAlive` es la probabilidad de seguir originando: por debajo de 0.5 el holdout trae 0.15 originaciones de media, y por encima 2.39. El Pareto/NBD baja el MAE de 0.913 a 0.716.

`R/12_recovery_by_n.R` repite la recuperación en 10 semillas y cinco tamaños, de 500 a 5,000. La tasa de compra queda cerca del 4% de error mediano desde 2,000 comercios. La de abandono sigue en 14% con 5,000. El +34% de la semilla 42 con 2,000 comercios entra en ese rango.

`R/13_identification.R` alarga esa grilla a 10,000 y 20,000. El 14% no era un techo: con 20,000 comercios el error mediano de la tasa de abandono baja a 4.9%. `s` y `beta` se mueven juntos (correlación 0.98) y cada uno se estima peor que el cociente.

`R/14_seasonality.R` compara cuatro semanas de diciembre con cuatro de junio en la cohorte de Online Retail. Diciembre está más activo (0.411 frente a 0.308 ocasiones). Aun así gana la tasa histórica en las dos ventanas, y repetir el diciembre anterior es el peor pronóstico (MAE 0.626): ese mes es la entrada del cliente, no una estación que se repite.

## Resultados

Holdout de 38.7 semanas, 2,357 clientes (`outputs/tables/03_holdout_metrics.csv` y `05_benchmark.csv`):

| Modelo | MAE | RMSE | Sesgo |
|---|---:|---:|---:|
| Pareto/NBD | 0.751 | 1.597 | −0.099 |
| GGom/NBD | 0.751 | 1.597 | −0.099 |
| BG/NBD | 0.782 | 1.602 | −0.101 |
| XGBoost | 0.908 | 1.677 | +0.002 |
| Baseline ingenuo | 1.018 | 2.199 | +0.439 |

Por AIC, en la ventana de estimación, gana BG/NBD (19,213.7 frente a 19,238.5 del Pareto/NBD). GGom/NBD empata el logLik del Pareto/NBD y no es un modelo distinto: `b` y `beta` caen al límite.

Ese holdout es uno solo. Con horizonte fijo de 13 semanas y cortes en 26, 39, 52 y 64 (`outputs/tables/08_rolling_origin_summary.csv`), el MAE medio es 0.330 para Pareto/NBD y GGom/NBD (sd 0.044), 0.335 para BG/NBD y 0.398 para el baseline. El orden se repite en los cuatro cortes. La ventaja del Pareto/NBD sobre BG/NBD es de unas cinco milésimas, menor que la dispersión entre cortes. Estos MAE no se comparan con los de 38.7 semanas: el horizonte es otro, y el error absoluto baja porque la cohorte compra menos.

Un intervalo bootstrap al 90% con 1,000 remuestreos (`09_cet_uncertainty_summary.csv`, `09_clv_uncertainty_summary.csv`) es un intervalo para la media, no para la próxima compra. La mediana del ancho del CET es el 32% de la predicción, y el conteo real del holdout cae dentro solo en el 2.3% de los clientes. En el CLV la mediana del ancho es el 87% del valor puntual. Sumar los extremos por cliente (178,039 a 439,766 alrededor de 317,281) no es un intervalo del total, porque los clientes comparten parámetros.

El decil superior concentra el 61.3% del CLV. Ese CLV es de horizonte infinito (5% de descuento → 455,354; 10% → 317,281; 15% → 254,668; 20% → 217,210). El horizonte mueve el gasto del período, no el CLV: 13 semanas → 22,654; 26 → 42,309; 52 → 75,713; 104 → 128,544.

En la simulación (3,000 clientes), $s$ y $\beta$ se recuperan con errores de −14.9% y −16.6%. $E[\lambda]$ y $E[\mu]$ vuelven a +1.1% y +2.0%.

## Limitaciones

- Sirve para contextos sin contrato. No aplica a suscripciones ni a préstamos.
- El holdout de 38.7 semanas sigue siendo uno. En las ventanas de 13 semanas el signo se repite y la ventaja sobre BG/NBD es pequeña frente a la dispersión entre cortes. El AIC en muestra sigue eligiendo BG/NBD.
- El agregado acumulado ajusta bien y los deciles bajos no: el modelo predice 0.108 compras donde se observan 0.251. Es una hipótesis, no un hallazgo cerrado.
- Spearman(frecuencia, gasto medio) = 0.165. El Gamma/Gamma asume independencia; la relación es débil y no es nula.
- XGBoost usa ventanas de distinto largo (19 frente a ~39 semanas), normalizadas a tasas, y hiperparámetros fijos. Su MAE aquí es 0.908; la referencia de la especificación, en R 4.3.3, daba 0.915. El orden es el mismo.
- Los covariables de apparel son simulados. Mejoran el ajuste (el dinámico baja el MAE de holdout de 2.040 a 1.858) y eso no es un efecto de negocio.

## Licencia

Código de este repositorio: MIT. CLVTools 0.12.1: GPL-3, como dependencia.

## Criterios de aceptación

| ID | Estado | Evidencia |
|---|---|---|
| A1 | Cumple | Clon limpio del commit de la fase 8, `renv::restore()` y `Rscript R/run_all.R`: código 0. |
| A2 | Cumple | Test de `features_at` en verde y `stopifnot` activo en `R/05_benchmark_xgboost.R`. |
| A3 | Cumple | `02_model_comparison.csv` y `03_holdout_metrics.csv`: tres BTYD más el baseline. |
| A4 | Cumple | `03_calibration_pnbd_deciles.csv` y `outputs/figures/03_tracking_pnbd.png`. |
| A5 | Cumple | XGBoost reportado con MAE peor que el Pareto/NBD; la limitación de diseño está en el reporte. |
| A6 | Cumple | `07_parameter_recovery.csv` y la lectura de identificabilidad en el reporte. |
| A7 | Cumple | Local: 20 pasadas, 0 fallos. CI: [run 44095269511](https://github.com/CarlosDsuarez/p7-clv-clvtools/actions/runs/44095269511), 20 pasadas, 0 fallos, 0 avisos. |
| A8 | Cumple | Este README y `reports/p7_clv.html`. |
| A9 | Cumple | `docs/decisiones.md`. No hubo cambio de parámetros. |
