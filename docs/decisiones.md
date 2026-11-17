# Registro de decisiones

Cada cambio de parámetro o desvío respecto a `P7_CLVTools_Especificacion.md` queda aquí, con la causa.

## 2026-11-17 — Entorno de la fase 1

- R local: 4.6.0 (2026-04-24), macOS. La especificación se ejecutó en R 4.3.3 sobre Ubuntu 24.04. No se baja de versión: la spec pide R ≥ 4.3. Si una cifra se aleja de forma material de los resultados de referencia, se investiga antes de seguir y se anota aquí.
- Dependencias aisladas con `renv`. Se versiona `renv.lock`.
- Licencia del repositorio: MIT. CLVTools 0.12.1 es GPL-3 y entra como dependencia, no como código copiado.
- `outputs/models/` queda fuera de git (binarios regenerables). Tablas y figuras sí se versionan: son la evidencia de cada corrida.

## Parámetros (sin cambios)

Fuente única: `R/00_utils.R`. No se modifican respecto a la especificación.

- `SEED = 42`: reproducibilidad fijada en la spec.
- `TIME_UNIT = "week"`: unidad temporal de CDNOW.
- `UNITS_PER_YEAR = 52`: el descuento de CLVTools es continuo por unidad de tiempo; con semanas se divide entre 52.
- `DISCOUNT_ANNUAL = 0.10`: tasa anual de la spec.
- `EST_SPLIT_WEEKS = 39`: corte de estimación del cohort CDNOW (39 semanas; holdout el resto de la ventana).

## 2026-11-17 — Corrida de `R/01_load_validate.R`

- `print(clvdata)`: 2,357 clientes, 6,696 transacciones. Estimación 1997-01-01 → 1997-10-01 (39 semanas). Holdout 1997-10-02 → 1998-06-30 (38.71429 semanas). Coincide con la spec.
- Paquetes en `renv.lock`: CLVTools 0.12.1, data.table 1.18.6.1, ggplot2 4.0.4, lubridate 1.9.5, R 4.6.0. El binario de data.table avisa que se compiló con R 4.6.1; no se recompiló.
- `plot(clv, which = "tracking")` avisó que ggplot2 4.0.4 recibió un numérico en `scale_x_date`. El PNG se escribió igual (`outputs/figures/01_tracking.png`, 82 KB). No se tocó la lógica del script.

## 2026-11-17 — Corrida de `R/02_fit_models.R`

Los tres modelos convergieron. Cifras de `outputs/tables/02_model_comparison.csv` (2,357 clientes). Coinciden con la referencia de la spec en la precisión que esa tabla publica.

- BG/NBD: logLik −9602.861, AIC 19213.72, BIC 19236.78. Gana por AIC.
- Pareto/NBD: logLik −9615.242, AIC 19238.48, BIC 19261.54. Coeficientes: r 0.551, alpha 10.555, s 0.625, beta 12.244.
- GGom/NBD: en la tabla impresa el logLik es el mismo que Pareto/NBD (−9615.242). En el CSV difieren en 1.3e-4 (−9615.24164 frente a −9615.24152). AIC 19240.48 solo sube por el parámetro extra. `coef()`: b = 1.92e-05, beta = 2.34e-04; r y alpha coinciden con Pareto/NBD. No es un modelo distinto: es el Pareto/NBD en el límite. No se cambió ningún parámetro.

## 2026-11-17 — Corrida de `R/03_holdout_validation.R`

Holdout de 38.7 semanas. Cifras de `outputs/tables/03_holdout_metrics.csv`. Coinciden con la referencia en la precisión publicada.

- Pareto/NBD: MAE 0.751, RMSE 1.597, sesgo −0.099.
- GGom/NBD: MAE 0.751, RMSE 1.597, sesgo −0.099 (empata con Pareto/NBD; el CSV difiere en el quinto decimal).
- BG/NBD: MAE 0.782, RMSE 1.602, sesgo −0.101.
- Baseline ingenuo: MAE 1.018, RMSE 2.199, sesgo +0.439.

El MAE del Pareto/NBD es ~26% menor que el del baseline (0.751 frente a 1.018). El AIC de la fase 2 prefería BG/NBD; el MAE de este único holdout prefiere Pareto/NBD, con una diferencia de ~4% y sin intervalo. No se concluye más que eso.

Calibración del Pareto/NBD (`03_calibration_pnbd_deciles.csv`): subestima en deciles bajos (decil 1: 0.108 predicho frente a 0.251 observado; decil 6: 0.164 frente a 0.343) y calibra bien arriba (decil 9: 1.308 frente a 1.254; decil 10: 3.865 frente a 3.737). La subestimación en baja actividad queda como hipótesis, no como resultado. El gráfico agregado está en `outputs/figures/03_tracking_pnbd.png`. Mismo aviso de `scale_x_date` que en la fase 1; el PNG se escribió.

## 2026-11-17 — Corrida de `R/04_spending_clv.R`

Gamma/Gamma convergió (KKT 1 y 2 verdaderos). LL −4055.80, AIC 8117.59, BIC 8134.89. Coeficientes: p 6.238, q 3.746, gamma 15.478. `summary` deja `z` y el p-valor en NA; no se reescribió el script.

- Spearman(frecuencia, gasto medio) = 0.165 en clientes con al menos dos compras en la estimación. Relación débil: el supuesto de independencia del Gamma/Gamma es razonable y no es perfecto. Queda como limitación.
- Decil superior: 61.3% del `predicted.CLV`.
- CLV total (horizonte infinito; `04_sensitivity_discount.csv`): 5% → 455,354; 10% → 317,281; 15% → 254,668; 20% → 217,210.
- Gasto esperado del período (`04_sensitivity_horizon.csv`, `predicted.period.spending`): 13 sem → 22,654; 26 → 42,309; 52 → 75,713; 104 → 128,544.

La sensibilidad al horizonte no usa `predicted.CLV`: esa columna es DERT por gasto medio, con horizonte infinito, y solo se mueve con el descuento. El descuento es la tasa continua semanal `log(1.10)/52`. Cifras alineadas con la referencia.

## 2026-11-17 — Corrida de `R/05_benchmark_xgboost.R`

xgboost 3.2.1.1, los mismos hiperparámetros de la spec (`count:poisson`, eta 0.05, max_depth 3, 150 rondas, semilla 42). El `stopifnot` de fuga temporal no se disparó. Los BTYD se comparan sobre los 2,357 clientes del holdout: su MAE reproduce la fase 3 al decimal que imprime data.table.

`outputs/tables/05_benchmark.csv`:

- Pareto/NBD: MAE 0.751, RMSE 1.597, sesgo −0.099.
- GGom/NBD: MAE 0.751, RMSE 1.597, sesgo −0.099.
- BG/NBD: MAE 0.782, RMSE 1.602, sesgo −0.101.
- XGBoost: MAE 0.908, RMSE 1.677, sesgo +0.002.
- Baseline: MAE 1.018, RMSE 2.199, sesgo +0.439.

La referencia de la spec trae XGBoost en MAE 0.915, RMSE 1.684 y sesgo +0.012. La diferencia es pequeña y no cambia el orden: XGBoost mejora al baseline (~11% de MAE) y queda ~21% peor que el Pareto/NBD, con sesgo casi nulo. No se retocaron hiperparámetros. La causa plausible es el binario (R 4.6.0 en macOS arm64 frente a R 4.3.3 en Ubuntu). Las ventanas de entrenamiento y test siguen sin el mismo largo (19 frente a ~39 semanas), normalizadas a tasas.

## 2026-11-17 — Corrida de `R/06_covariates.R`

`estimation.split = 104` semanas en apparel, como fija la spec (con 40 el Pareto/NBD base no converge). Los tres ajustes convergieron. `outputs/tables/06_covariates_comparison.csv`:

- Dinámico: AIC 11525.87, holdout MAE 1.858.
- Estático: AIC 11658.13, holdout MAE 2.007.
- Base: AIC 11704.20, holdout MAE 2.040.

Razón de verosimilitud estático contra base: Chi-cuadrado 54.07 con 4 grados de libertad, p = 5.087e-11. Los covariables de apparel son simulados: el p-valor solo confirma que el mecanismo de CLVTools responde, no un efecto de negocio. Solo el Pareto/NBD admite covariables dinámicas. Cifras alineadas con la referencia.

## 2026-11-17 — Corrida de `R/07_simulation_recovery.R` y `R/run_all.R`

Simulación de 3,000 clientes, semilla 42, parámetros verdaderos de la spec. `outputs/tables/07_parameter_recovery.csv`:

- r: 0.543 frente a 0.553 (−1.9%).
- alpha: 10.264 frente a 10.578 (−3.0%).
- s: 0.516 frente a 0.606 (−14.9%).
- beta: 9.735 frente a 11.669 (−16.6%).
- E[λ] = r/alpha: 0.0529 frente a 0.0523 (+1.1%).
- E[μ] = s/beta: 0.0530 frente a 0.0519 (+2.0%).

s y beta se recuperan peor (débilmente identificados y correlacionados). Las medias implícitas son la comparación fiable. Cifras alineadas con la referencia.

`Rscript R/run_all.R` con `outputs/` vacío terminó con código 0. Tiempos: 01 1.0 s, 02 0.8 s, 03 0.4 s, 04 0.2 s, 05 0.1 s, 06 43.4 s, 07 0.4 s. Las tablas ya versionadas no cambiaron al regenerarse. La biblioteca de renv ya estaba instalada; un `renv::restore()` desde cero queda para la comprobación de A1 en la fase 9.

## 2026-11-17 — Tests locales

`testthat::test_dir("tests/testthat", stop_on_failure = TRUE)`: FAIL 0, PASS 20, WARN 1. El aviso es el de data.table compilado con R 4.6.1, no un fallo de aserción. El `stopifnot` de fuga temporal del paso 5 sigue en el script; el test de `features_at` cubre el mismo corte. El workflow de CI es el de la spec, sin cambios, hasta ver la primera corrida en GitHub Actions.
