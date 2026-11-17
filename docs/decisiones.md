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
