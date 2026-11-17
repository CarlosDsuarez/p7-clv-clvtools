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

`testthat::test_dir("tests/testthat", stop_on_failure = TRUE)`: FAIL 0, PASS 20, WARN 1. El aviso es el de data.table compilado con R 4.6.1, no un fallo de aserción. El `stopifnot` de fuga temporal del paso 5 sigue en el script; el test de `features_at` cubre el mismo corte.

## 2026-11-17 — CI, clon limpio y reporte

- GitHub Actions [run 44095269511](https://github.com/CarlosDsuarez/p7-clv-clvtools/actions/runs/44095269511): FAIL 0, WARN 0, PASS 20. El `ci.yml` de la spec no se modificó. Actions avisa que `checkout@v4` apunta a Node 20; el job igual terminó en verde.
- A1: clon limpio del commit `8b1bf1e`, `renv::restore()` y `Rscript R/run_all.R` terminaron con código 0.
- Para el reporte se añadieron a renv `knitr` 1.52 y `rmarkdown` 2.32. No entran en el ajuste de los modelos.
- Quarto 1.11.9 produjo `reports/p7_clv.html`. El paquete de macOS pedía contraseña de administrador; se usó el tarball en el directorio del usuario. Quarto no es dependencia de `run_all.R`.
- Las cifras del README y del html salen de `outputs/tables/*.csv`. El Spearman 0.165 se vuelve a calcular en el reporte con la misma fórmula del paso 4, porque el script solo lo imprime y no lo guarda en un CSV.

## 2026-11-17 — Ventanas móviles (`R/08_rolling_origin.R`)

Extensión de la sección 11 de la spec. No se modificó `EST_SPLIT_WEEKS` ni `R/run_all.R`: el pipeline de las fases 1–7 queda igual y este paso se corre aparte.

- Horizonte fijo de 13 semanas, para que el MAE sea comparable entre cortes. Cortes: 26, 39, 52 y 64. El 64 es el más tardío que aún deja 13 semanas antes del fin de CDNOW (77.86 semanas). El 39 es el corte canónico, con otro horizonte: estos MAE no se comparan con `03_holdout_metrics.csv`.
- 2,357 clientes en los cuatro cortes.
- MAE medio (`08_rolling_origin_summary.csv`): GGom/NBD 0.330 (sd 0.044), Pareto/NBD 0.330 (sd 0.044), BG/NBD 0.335 (sd 0.045), baseline 0.398 (sd 0.059).
- En los cortes 26 y 64 el GGom tiene el mismo logLik que el Pareto/NBD y `b` del orden de 1e-6. Sigue siendo el mismo modelo.
- En los cuatro cortes los BTYD baten al baseline y el Pareto/NBD queda por debajo de BG/NBD. La diferencia media de MAE entre esos dos es ~0.005, menor que la sd entre cortes. El signo es estable; el tamaño de la ventaja no.
- El MAE absoluto cae del corte 26 (0.387) al 64 (0.286) para el Pareto/NBD porque la cohorte compra menos, no porque el modelo se vuelva más preciso en esa proporción.

## 2026-11-17 — Incertidumbre (`R/09_uncertainty.R`)

Extensión de la sección 11. No se modificó `EST_SPLIT_WEEKS` ni `run_all.R`.

- `predict(..., uncertainty = "boots", level = 0.9)`. El default `num.boots = 100` dispara el aviso de CLVTools de que recomienda 1,000 o más. Se usan 1,000, con semilla 42 antes de cada llamada. El modelo es el Pareto/NBD reajustado en el script; el CET puntual reproduce los deciles de `03_calibration_pnbd_deciles.csv` y el CLV total al 10% reproduce `04_sensitivity_discount.csv` (317,281).
- El intervalo es de la media (CET o CLV), no de la compra observada. Cobertura del conteo real del holdout: 2.3%. En los deciles 1 a 7 es 0. La estimación puntual cae dentro del intervalo en el 100% de los clientes. Mediana del ancho del CET: 0.047 transacciones, 32% de la predicción.
- CLV: mediana del ancho 87% del valor puntual. La suma de los extremos inferiores es 178,039 y la de los superiores 439,766. No se presenta como intervalo del total: los clientes comparten el mismo sorteo de parámetros.

## 2026-11-17 — Pipeline con targets (`_targets.R`)

Extensión de la sección 11. No se modificó la lógica de los scripts ni `EST_SPLIT_WEEKS`. `run_all.R` sigue corriendo solo los pasos 01–07.

- `targets` 1.12.0. Cada target hace `source()` del script existente y declara los archivos que ese script ya escribía. La caché invalida un paso si cambia el script o un archivo del que depende (por ejemplo, el holdout depende del RDS de los ajustes).
- `_targets/` no se versiona: es caché local. Los CSV y las figuras sí.
- Primera `tar_make()`: 21 pasos, 5 min 57 s, 0 saltados. Los CSV no cambiaron respecto a la corrida anterior. Segunda `tar_make()`, sin tocar nada: 21 saltados, 44 ms.
- Tres targets avisan lo ya conocido: data.table compilado con R 4.6.1 y `scale_x_date` en los gráficos de CLVTools. No se cambió el código por eso.

## 2026-11-17 — Tablero Shiny (`shiny/app.R`)

Extensión de la sección 11. No se reajustan modelos ni se cambia `EST_SPLIT_WEEKS`.

- shiny 1.14.0 y DT 0.34.0. La app lee `04_clv_pnbd_52w.csv` y `09_clv_intervals.csv`. El CLV que muestra es el de horizonte infinito al 10%; el CET de esa tabla es a 52 semanas, no el holdout de 38.7.
- Filtros: P(activo) mínima, CLV mínimo e Id. Sin filtro muestra 2,357 clientes y CLV 317,281 (100%). Con Id `509` quedan 2 clientes (509 y 1509) y CLV 5,306 (1.7%). Con P(activo) ≥ 0.95 quedan 137 clientes y CLV 103,924 (32.8%). Un Id inexistente deja la tabla vacía y el gráfico dice que nadie pasa el filtro.
- El filtro está en `R/dashboard_filter.R`. `test-dashboard.R`: 4 pasadas. No entra en `run_all.R` ni en `targets`.

## 2026-11-17 — Online Retail II (`R/10_online_retail.R`)

Fase B de la spec. No se modificó `EST_SPLIT_WEEKS` ni `run_all.R`. El xlsx de UCI queda en `data/raw/` y no se versiona. Tampoco entra en `targets`: sin el archivo, `tar_make()` dejaría de ser reproducible desde el clon.

- 1,067,371 líneas, 2009-12-01 a 2011-12-09. Se tiran 243,007 sin `Customer ID`, las cantidades o precios no positivos y las facturas que empiezan por C. Una ocasión es un cliente-día: 36,969 facturas se agregan al día. Quedan 5,878 clientes identificados.
- Cohorte: primera compra en las primeras 13 semanas. Son 1,729 clientes y 14,113 ocasiones dentro de las 78 semanas que se conservan (estimación 39, holdout hasta 2011-05-31). La serie cruda dura 105 semanas; el corte iguala el largo de CDNOW. CLVTools imprime un holdout de 38.857 semanas. El `H_weeks` del script, medido desde el día del corte hasta el último día incluido, es 39.
- AIC y holdout eligen BG/NBD. MAE 2.026 frente a 2.041 del baseline: menos de un 1%. En CDNOW esa ventaja era ~26% (`10_vs_cdnow.csv`). El GGom/NBD tiene `b` = 0.006 y un logLik casi igual al Pareto/NBD.
- Decil 1: predicho 0.723, observado 0.727. No se repite la subestimación de CDNOW. El decil superior concentra el 55.3% del CLV (CDNOW, 61.3%).
- El minorista es estacional y el modelo no tiene calendario. El empate con el baseline es de este diseño, no una conclusión general.

## 2026-11-17 — Comercios BNPL sintéticos (`R/11_bnpl_merchants.R`)

Última extensión de la sección 11. No hay un archivo P13 en esta máquina, así que no se usa una cartera ajena. El panel lo genera `simulate_bnpl_merchants()` con el Pareto/NBD de `R/simulate.R`: 2,000 comercios, semilla 42, primera originación en las primeras 12 semanas, ventana de 78. `EST_SPLIT_WEEKS` sigue en 39. No entra en `run_all.R` ni en `targets`.

- `Id` es el comercio, `Date` un día con originación y `Price` el monto de esa ocasión. `PAlive` es la probabilidad de seguir originando. No es probabilidad de repago ni de default.
- Holdout (`11_holdout_metrics.csv`): Pareto/NBD MAE 0.716, GGom/NBD 0.716, BG/NBD 0.747, baseline 0.913. La ventaja frente al baseline vuelve cuando los datos salen del modelo. En Online Retail II era menor al 1%.
- Actividad futura (`11_palive_summary.csv`): media de PAlive 0.487. El 73.2% queda bajo 0.5 y en el holdout origina 0.15 veces de media. Quienes están en 0.5 o más originan 2.39. En el decil de mayor monto durante la estimación, solo el 13.5% tiene PAlive bajo 0.5.
- Recuperación (`11_parameter_recovery.csv`): con 2,000 comercios \(E[\lambda]\) erra −5.3% y \(E[\mu]\) +34.5%. Peor que la simulación de 3,000, donde las medias volvían a 1–2%. El orden de la actividad futura se sostiene igual. No se sube `n` después de ver el error.

## 2026-11-17 — Tamaño de muestra de la recuperación (`R/12_recovery_by_n.R`)

La grilla se escribió antes de correrla: n = 500, 1,000, 2,000, 3,000 y 5,000; semillas 1 a 10; mismos parámetros y el mismo corte de 39 semanas. No se reusa la semilla 42. No se cambia `EST_SPLIT_WEEKS`. No entra en `run_all.R` ni en `targets`.

- Resumen en `12_recovery_by_n_summary.csv`. La cifra que se lee es la mediana del error absoluto. La media no sirve a n = 1,000: una semilla llega a +905% en \(E[\mu]\).
- Ajustes con coeficientes `NA`: 1 de 10 en n = 500 y 2 de 10 en n = 1,000. Desde 2,000, los 10 convergen.
- \(E[\lambda]\): mediana del error absoluto 7.9% (500), 4.5% (2,000), 3.8% (5,000).
- \(E[\mu]\): 42.6% (500), 25.2% (2,000), 16.8% (3,000), 14.1% (5,000). A n = 2,000 el rango de las diez semillas es −45% a +47%, así que el +34.5% de la semilla 42 no es un caso aparte.
- El +2% de la simulación de 3,000 con semilla 42 fue un sorteo favorable frente a estas diez semillas.

## 2026-11-17 — Más muestra y correlación de s y beta (`R/13_identification.R`)

Grilla fijada antes de correrla: las mismas semillas 1 a 10, los tamaños de la fase anterior, más 10,000 y 20,000. No se cambia `EST_SPLIT_WEEKS` ni la semilla 42. No entra en `run_all.R` ni en `targets`.

- Los tamaños 500 a 5,000 reproducen `12_recovery_by_n_summary.csv`: la diferencia máxima de la mediana del error absoluto es 4.9e-16.
- \(E[\mu]\), mediana del error absoluto: 14.1% con 5,000, 11.1% con 10,000, 4.9% con 20,000. El 14% no era un techo.
- \(E[\lambda]\) con 20,000: 1.9%.
- En el mismo n = 20,000, \(s\) queda en 8.0% y \(\beta\) en 11.8%. El cociente se estima mejor que cada parámetro.
- Correlación entre semillas de las estimaciones de \(s\) y \(\beta\): 0.98 con 20,000 comercios, y entre 0.92 y 1.00 en todos los tamaños (`13_param_correlation.csv`). Se mueven juntos.

## 2026-11-17 — Estacionalidad en Online Retail (`R/14_seasonality.R`)

Hipótesis escrita en el script antes de mirar el MAE: en las cuatro semanas del 2010-12-01 al 2010-12-29, repetir el mismo tramo de 2009 empata o gana a los BTYD; en las cuatro semanas del 2011-06-01 al 2011-06-29, los BTYD bajan el MAE de la tasa histórica. Misma cohorte de 13 semanas y el mismo `EST_SPLIT_WEEKS = 39`. El holdout guardado se alarga a 48 semanas para que junio de 2011 quepa. No entra en `run_all.R` ni en `targets`, porque el xlsx no está en el repo.

- Diciembre tiene más actividad que junio: 0.411 frente a 0.308 ocasiones de media (`14_seasonality_mae.csv`).
- La hipótesis no se sostiene. En diciembre el MAE es 0.413 (tasa), 0.436 (BG/NBD), 0.439 (Pareto/NBD) y 0.626 (estacional). El estacional sesga +0.38: el primer diciembre es la entrada a la cohorte.
- En junio el orden es el mismo: tasa 0.371, BG/NBD 0.386, Pareto/NBD 0.390, estacional 0.390.
- El empate del holdout largo con el baseline no se explica solo por Navidad. En las dos ventanas la tasa histórica queda por delante, por poco.

## 2026-11-17 — Orden de quién compra (`R/15_ranking.R`)

Hipótesis escrita antes de mirar el Spearman: en las mismas ventanas de `R/14_seasonality.R`, BG/NBD y Pareto/NBD superan a la tasa histórica. El MAE de cuatro semanas tiene muchos ceros (compra el 27.2% en diciembre y el 22.8% en junio), así que se mira el orden y no solo el error absoluto. No se cambia `EST_SPLIT_WEEKS`. No entra en `run_all.R` ni en `targets`.

- Cohorte completa, diciembre: Spearman 0.451 (tasa), 0.448 (Pareto/NBD), 0.448 (BG/NBD), 0.358 (estacional).
- Cohorte completa, junio: 0.413 (tasa), 0.412 (BG/NBD), 0.411 (Pareto/NBD), 0.321 (estacional).
- Repetidores (al menos dos compras en la estimación), diciembre: Pareto/NBD 0.410 frente a tasa 0.408. Junio: BG/NBD 0.372 frente a tasa 0.368.
- La hipótesis no se sostiene. El modelo no ordena mejor quién compra. La diferencia a favor de los repetidores cabe en el tercer decimal. El MAE de la fase 14 se reproduce en `mae_all`.

## 2026-11-17 — Orden en el holdout de 39 semanas (`R/16_holdout_rank.R`)

Hipótesis escrita antes de mirar el resultado: en la cohorte y el holdout de `R/10_online_retail.R`, el Spearman y la parte de compras futuras capturada por el decil superior del Pareto/NBD y del BG/NBD superan a la tasa histórica. No se cambia `EST_SPLIT_WEEKS`. No entra en `run_all.R` ni en `targets`.

- Spearman (`16_holdout_rank.csv`): tasa 0.655, BG/NBD 0.655, GGom/NBD 0.652, Pareto/NBD 0.652.
- Decil superior: tasa 38.2% de las compras del holdout; los tres BTYD, 38.3%.
- El MAE reproduce la fase 10: BG/NBD 2.026, tasa 2.041, mismos 1,729 clientes.
- La hipótesis no se sostiene. En este corte el modelo no ordena mejor a los clientes ni concentra mejor las compras futuras. La ventaja de MAE, de menos de un 1%, no viene de un mejor ranking.

## 2026-11-17 — MAE por frecuencia (`R/17_frequency_strata.R`)

Hipótesis escrita antes de mirar el error: con una sola ocasión en la estimación, Pareto/NBD y BG/NBD tienen menor MAE que la tasa; con 6 o más, la tasa empata o gana. Tramos fijados: 1, 2, 3-5, 6+. Mismo `EST_SPLIT_WEEKS = 39` en CDNOW y en la cohorte de Online Retail. No entra en `run_all.R` ni en `targets`.

- La hipótesis no se sostiene, y el sentido es el contrario en el tramo de una compra. Ahí la tasa predice 0 y gana el MAE: CDNOW 0.237 frente a 0.334 del Pareto/NBD (1,411 clientes); Online Retail 0.706 frente a 0.853 (388 clientes). El modelo les pone a todos una expectativa positiva y la mayoría no vuelve.
- Con 6 o más, la tasa se pasa. CDNOW: predice 9.28 donde se observan 4.77 (MAE 5.79 frente a 3.26 del BG/NBD, 132 clientes). Online Retail: predice 10.73 donde se observan 8.99 (MAE 4.22 frente a 3.97, 408 clientes).
- El agregado de CDNOW lo deciden esos repetidores, aunque sean pocos. En el minorista el exceso de la tasa es chico y los tramos de una a cinco compras, donde la tasa no pierde, son la mayoría (1,321 de 1,729). Por eso allí el MAE total casi empata.

## 2026-11-17 — Denominador de la tasa (`R/18_short_age.R`)

Hipótesis escrita antes de mirar el error: en el tramo de 6 o más, el exceso de `(n-1)/edad` está en la segunda mitad de las 39 semanas (`first_wk >= 19.5`), y dividir siempre entre 39 acerca ese MAE al BG/NBD. En la primera mitad las dos tasas debían parecerse. Mismos datos que la fase 17. No entra en `run_all.R` ni en `targets`.

- El tramo tardío tiene 0 clientes en los dos datasets. Los 132 de CDNOW y los 408 del minorista empezaron todos en la primera mitad. La hipótesis no se puede sostener: no hay denominadores de unas pocas semanas en ese tramo.
- CDNOW, primera mitad (`18_short_age.csv`): la tasa individual predice 9.28 (MAE 5.79), la tasa sobre 39 semanas predice 7.92 (MAE 4.97), el BG/NBD predice 4.50 (MAE 3.26), lo observado es 4.77. Alargar el denominador cierra una parte y deja la mayor parte del exceso.
- Online Retail, misma celda: tasa individual 10.73 (MAE 4.22), tasa sobre 39 semanas 10.17 (MAE 3.96), BG/NBD 9.38 (MAE 3.97), observado 8.99. Ahí el denominador fijo ya empata al modelo.

## 2026-11-17 — Última compra (`R/19_recency_gap.R`)

Hipótesis escrita antes de mirar el error: el exceso que queda al dividir entre 39 semanas, en el tramo de 6 o más, está en quienes no compran desde la primera mitad (`last_wk < 19.5`). Ahí el BG/NBD baja el MAE de esa tasa. Quienes compran en la segunda mitad siguen activos y ahí la tasa empata o gana. Mismos datos que la fase 18. No entra en `run_all.R` ni en `targets`. Las dos celdas suman los 132 y los 408 del tramo anterior.

- La hipótesis no se sostiene en CDNOW (`19_recency_gap.csv`). La celda quieta tiene 8 clientes (última compra en la semana 13.3, P(activo) del BG/NBD 0.05). La tasa sobre 39 semanas predice 7.47 y se observan 1.50; el BG/NBD baja a 0.23.
- Los otros 124 compraron en la segunda mitad (semana 33.6) y la P(activo) es 0.72. La tasa predice 7.95 donde se observan 4.98 (MAE 4.90). El BG/NBD predice 4.77 (MAE 3.38). El exceso de la fase 18 sigue en clientes a los que el modelo da por activos.
- Online Retail: 403 de 408 están en la segunda mitad, con P(activo) 0.996. El MAE de la tasa sobre 39 semanas es 3.95 y el del BG/NBD 3.98. Los 5 quietos no mueven el tramo.
