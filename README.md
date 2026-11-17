# P7 · Customer Lifetime Value con CLVTools

En un negocio sin contrato el abandono no se observa: solo se ve que el cliente dejó de comprar. Este proyecto estima, para cada cliente de CDNOW, cuántas compras hará en el holdout, si sigue activo y cuánto vale. Compara Pareto/NBD, BG/NBD y GGom/NBD contra un baseline ingenuo y contra un XGBoost con el mismo corte temporal. No es un tutorial: el criterio es el error fuera de tiempo, y el informe dice dónde el modelo falla.

El reporte renderizado está en [`reports/p7_clv.html`](reports/p7_clv.html). Las cifras de abajo salen de `outputs/tables/` de esta corrida (R 4.6.0, CLVTools 0.12.1, xgboost 3.2.1.1).

## Cómo correrlo

Hace falta R ≥ 4.3. CLVTools es GPL-3; si se compila desde fuente hace falta GNU GSL. En macOS arm64 esta corrida usó binarios de CRAN.

```bash
Rscript -e 'renv::restore()'
Rscript R/run_all.R
Rscript -e 'testthat::test_dir("tests/testthat", stop_on_failure = TRUE)'
quarto render reports/p7_clv.qmd
```

Los parámetros viven en `R/00_utils.R` (semilla 42, unidad semanal, descuento anual 10%, corte a las 39 semanas). Un cambio se anota en `docs/decisiones.md`. `outputs/models/` no se versiona: `run_all.R` lo regenera.

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

El decil superior concentra el 61.3% del CLV. Ese CLV es de horizonte infinito (5% de descuento → 455,354; 10% → 317,281; 15% → 254,668; 20% → 217,210). El horizonte mueve el gasto del período, no el CLV: 13 semanas → 22,654; 26 → 42,309; 52 → 75,713; 104 → 128,544.

En la simulación (3,000 clientes), $s$ y $\beta$ se recuperan con errores de −14.9% y −16.6%. $E[\lambda]$ y $E[\mu]$ vuelven a +1.1% y +2.0%.

## Limitaciones

- Sirve para contextos sin contrato. No aplica a suscripciones ni a préstamos.
- Hay un solo holdout. La ventaja del Pareto/NBD sobre BG/NBD es de un 4% y no trae intervalo. El AIC elige el otro modelo.
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
