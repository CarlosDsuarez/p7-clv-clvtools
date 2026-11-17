# P7 · Customer Lifetime Value con CLVTools (R) — Especificación de proyecto

> **Qué es este archivo.** Una especificación ejecutable para construir el proyecto P7 completo, pensada para leerla tú y para dársela a un asistente de código (Cursor, Claude Code). Todo el código de las secciones 6 y 7 (salvo el workflow de CI) viene de scripts que **ejecuté** antes de escribir este documento; la sección 14 dice exactamente qué se probó y qué no.
>
> **Versión del documento:** 2026-11-16 · **Entorno de prueba:** R 4.3.3, CLVTools 0.12.1 (CRAN, GPL-3), Ubuntu 24.04.
> **Esfuerzo estimado:** 45–50 h [ESTIMADO] · **Nivel:** semi-senior (con las mejoras de las secciones 6–9) · **Lenguaje:** R

---

## 1. Objetivo y preguntas que el proyecto debe responder

**Pregunta de negocio.** En un negocio donde el cliente no firma contrato (retail, e-commerce, hoteles), el abandono no se observa: solo se ve que dejó de comprar. ¿Cuántas compras hará cada cliente en los próximos meses, qué probabilidad hay de que siga activo y cuánto vale?

**Qué demuestra el proyecto** (esto es lo que lo hace de portafolio y no un tutorial): validación estrictamente fuera de tiempo, comparación contra un baseline ingenuo y contra ML supervisado con diseño justo, estudio de simulación que prueba que entiendes el modelo, y análisis honesto de dónde falla.

| ID | Pregunta falsable | Dónde se responde |
|---|---|---|
| Q1 | ¿Los modelos BTYD superan a un baseline ingenuo en el holdout? | Paso 3 |
| Q2 | ¿El criterio en muestra (AIC) y el error en holdout eligen el mismo modelo? | Pasos 2 y 3 |
| Q3 | ¿En qué deciles de actividad se calibra mal el modelo? | Paso 3 |
| Q4 | ¿Un XGBoost sobre variables RFM, con diseño temporal justo, supera o empata a los BTYD? | Paso 5 |
| Q5 | ¿Cuánto cambia el valor total al variar la tasa de descuento y el horizonte? ¿Cuánto del valor concentra el decil superior? | Paso 4 |
| Q6 | ¿Mejoran las covariables el ajuste y la predicción? (con la salvedad de que son simuladas) | Paso 6 |
| Q7 | ¿El estimador recupera los parámetros verdaderos cuando los datos vienen del modelo? | Paso 7 |

## 2. Alcance

**Incluye:** Pareto/NBD, BG/NBD y GGom/NBD; modelo de gasto Gamma/Gamma; covariables estáticas y dinámicas (solo Pareto/NBD admite dinámicas); validación out-of-time; benchmark XGBoost; simulación; tests; CI; reporte Quarto.

**No incluye:** suscripciones o préstamos (el abandono allí sí se observa; CLVTools modela contextos **sin contrato**), despliegue en producción, ni modelos bayesianos.

## 3. Datos

| Dataset | Uso | Tamaño / ventana | Nota |
|---|---|---|---|
| `cdnow` (incluido en CLVTools) | Dataset principal: modelos, holdout, benchmark | 2,357 clientes, 6,696 transacciones; estimación 1997-01-01 → 1997-10-01 (39 sem), holdout 38.7 sem | Cohorte de primeros compradores del primer trimestre de 1997 |
| `apparelTrans` + `apparelStaticCov` + `apparelDynCov` | Solo covariables (Paso 6) | 600 clientes; transacciones de 2005-01 a 2010-12 | **Los covariables son simulados**: aprendes la mecánica, no un efecto real |
| Simulación propia (`R/simulate.R`) | Recuperación de parámetros (Paso 7) | 3,000 clientes, ventana de 78 semanas | Parámetros conocidos |
| **Fase B (opcional)** | Datos reales propios | Id, Date, Price; ≥ 1 año de historia | Online Retail II (UCI) es una opción conocida; **no la verifiqué** en esta sesión |

Columnas mínimas para cualquier dataset propio: `Id`, `Date`, `Price`. Define explícitamente la cohorte (quién entra, cuándo hizo su primera compra) en `docs/decisiones.md`.

## 4. Entorno y reproducibilidad

- **R ≥ 4.3** (probado con 4.3.3). **CLVTools 0.12.1**; con los binarios de CRAN normalmente no necesitas compilar. Si compilas desde fuente necesitas GNU GSL (`sudo apt-get install libgsl-dev` en Ubuntu).
- **Paquetes:** `CLVTools`, `data.table`, `ggplot2`, `lubridate` (viene con CLVTools), `xgboost`, `testthat`, `knitr`, `rmarkdown` (o Quarto).
- **renv:** `renv::init()` al empezar, `renv::snapshot()` al terminar cada fase, y commitea `renv.lock`. Sin lockfile el proyecto cuenta como R0 en reproducibilidad.
- **Problema real que encontré:** en Ubuntu, `install.packages()` falló al compilar `fs` por falta de `uv.h`, y eso tumbó `testthat` y CLVTools en cascada. Lo resolví instalando el binario del sistema (`sudo apt-get install r-cran-fs r-cran-testthat`).
- **Docker (opcional, no probado):** base `rocker/r-ver:4.3.3` + `libgsl-dev` + `renv::restore()`.
- **Licencia:** CLVTools es GPL-3. Declara las dependencias en el README y revisa la compatibilidad antes de publicar; esto no es asesoría legal.

## 5. Estructura del repositorio

```text
p7-clv-clvtools/
├── README.md                    # problema, resultados, limitaciones, cómo correr
├── LICENSE
├── renv.lock
├── .gitignore                   # data/raw, outputs/models, .Rproj.user
├── .github/workflows/ci.yml
├── R/
│   ├── 00_utils.R               # parámetros, métricas, validación, carga de CDNOW
│   ├── features.R               # features RFM + objetivo con corte temporal estricto
│   ├── simulate.R               # simulador Pareto/NBD
│   ├── 01_load_validate.R
│   ├── 02_fit_models.R
│   ├── 03_holdout_validation.R
│   ├── 04_spending_clv.R
│   ├── 05_benchmark_xgboost.R
│   ├── 06_covariates.R
│   ├── 07_simulation_recovery.R
│   └── run_all.R
├── tests/testthat/
│   ├── test-metrics.R
│   ├── test-data.R
│   └── test-simulation.R
├── reports/p7_clv.qmd
├── docs/decisiones.md           # registro de decisiones y cambios de parámetros
└── outputs/{figures,tables,models}/
```

## 6. Pipeline paso a paso

Ejecuta siempre desde la raíz del repo: `Rscript R/01_load_validate.R`, etc., o todo con `Rscript R/run_all.R`. Cada paso escribe tablas en `outputs/tables/` y figuras en `outputs/figures/`.

> **Los "resultados de referencia" son de mi corrida** (R 4.3.3, CLVTools 0.12.1). Los tuyos deberían ser muy parecidos; si difieren de forma material, investiga antes de seguir (versiones, semilla, datos).

### 6.0 Base compartida: utilidades, features y simulador

`R/00_utils.R` es la única fuente de verdad de los parámetros (semilla, unidad de tiempo, descuento, corte de estimación). **Cambiar un parámetro implica registrarlo en `docs/decisiones.md`.**

```r
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
```

`R/features.R` construye las variables RFM **solo con datos hasta `t1`** y el objetivo **solo después de `t1`**. Es la pieza que previene la fuga temporal y la que tiene test unitario.

```r
# archivo: R/features.R
suppressPackageStartupMessages(library(data.table))

# Características RFM por cliente usando SOLO transacciones con wk <= t1.
# `tx` debe tener: Id, Price, wk (semanas desde la primera fecha del dataset).
features_at <- function(tx, t1) {
  w <- tx[wk <= t1]
  f <- w[, .(first_wk = min(wk), last_wk = max(wk), n = .N,
             mean_spend = mean(Price), total_spend = sum(Price)), by = Id]
  f[, `:=`(x = n - 1, T_age = pmax(t1 - first_wk, 1e-6), t_x = last_wk - first_wk)]
  # Variables sin escala (tasas y ratios) para que ventanas de distinto largo sean comparables
  f[, `:=`(rate_x = x / T_age, rec_ratio = t_x / T_age, spend_rate = total_spend / T_age)]
  f[]
}

# Variable objetivo: nº de transacciones en (t1, t1 + H]
target_in <- function(tx, t1, H) {
  tx[wk > t1 & wk <= t1 + H, .(y = .N), by = Id]
}

make_set <- function(tx, t1, H) {
  s <- merge(features_at(tx, t1), target_in(tx, t1, H), by = "Id", all.x = TRUE)
  s[is.na(y), y := 0L]
  s[, y_rate := y / H]
  s[]
}

FEATURE_COLS <- c("rate_x", "rec_ratio", "mean_spend", "spend_rate")
```

`R/simulate.R` genera transacciones de un proceso Pareto/NBD con parámetros conocidos.

```r
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
```

### 6.1 Carga, validación y EDA

Valida el esquema, construye el objeto `clvdata` y guarda 4 gráficos (seguimiento, frecuencia, gasto, tiempo entre compras). Debes ver 2,357 clientes y 6,696 transacciones.

```r
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
```

### 6.2 Ajuste y comparación de modelos

```r
# archivo: R/02_fit_models.R
source("R/00_utils.R")
suppressPackageStartupMessages({ library(CLVTools); library(data.table) })
ensure_dirs(); set.seed(SEED)

d <- load_cdnow_clv()

fit_safe <- function(expr) tryCatch(expr, error = function(e) {
  message("Ajuste fallido: ", conditionMessage(e)); NULL })

fits <- list(
  pnbd    = fit_safe(pnbd(d$clv,    verbose = FALSE)),
  bgnbd   = fit_safe(bgnbd(d$clv,   verbose = FALSE)),
  ggomnbd = fit_safe(ggomnbd(d$clv, verbose = FALSE))
)
fits <- Filter(Negate(is.null), fits)

comparison <- rbindlist(lapply(names(fits), function(m) {
  f <- fits[[m]]
  data.table(model = m, logLik = as.numeric(logLik(f)),
             AIC = AIC(f), BIC = BIC(f), n_customers = nobs(f))
}))[order(AIC)]
print(comparison)

fwrite(comparison, "outputs/tables/02_model_comparison.csv")
saveRDS(fits, "outputs/models/fits_cdnow.rds")
cat("02 OK\n")
```

**Resultado de referencia:**

| Modelo | logLik | AIC | BIC |
|---|---|---|---|
| BG/NBD | −9,602.9 | **19,213.7** | 19,236.8 |
| Pareto/NBD | −9,615.2 | 19,238.5 | 19,261.5 |
| GGom/NBD | −9,615.2 | 19,240.5 | 19,269.3 |

**Qué analizar (Q2):**
- Por AIC gana el BG/NBD en CDNOW.
- El GGom/NBD tiene el **mismo logLik que el Pareto/NBD** porque converge a un caso límite (`b ≈ 0`, `beta ≈ 0.0002` en mi corrida; revísalo con `coef()`). No lo presentes como un modelo distinto: es el Pareto/NBD con un parámetro de más.

### 6.3 Validación en holdout

Compara cada modelo contra lo que **realmente** ocurrió después del corte, calculado de forma independiente a CLVTools, y contra un baseline ingenuo que extrapola la tasa de compra repetida de cada cliente.

```r
# archivo: R/03_holdout_validation.R
source("R/00_utils.R")
suppressPackageStartupMessages({ library(CLVTools); library(data.table) })
ensure_dirs()

d    <- load_cdnow_clv()
fits <- readRDS("outputs/models/fits_cdnow.rds")

# --- Realidad observada en el holdout (calculada de forma independiente) -----
tx <- copy(d$tx)[, Date := lubridate::ymd(Date)]
origin     <- min(tx$Date)
split_date <- origin + EST_SPLIT_WEEKS * 7
H          <- as.numeric(difftime(max(tx$Date), split_date, units = "weeks"))
actual     <- tx[Date > split_date, .(actual = .N), by = Id]
actual[, Id := as.character(Id)]

# --- Baseline ingenuo: extrapolar la tasa de compra repetida observada --------
est <- tx[Date <= split_date,
          .(n = .N, first_wk = as.numeric(difftime(min(Date), origin, units = "weeks"))),
          by = Id]
est[, naive := (n - 1) / pmax(EST_SPLIT_WEEKS - first_wk, 1e-6) * H]
est[, Id := as.character(Id)]

# --- Predicciones de cada modelo para el holdout ------------------------------
preds <- rbindlist(lapply(names(fits), function(m) {
  p <- as.data.table(predict(fits[[m]], predict.spending = FALSE, verbose = FALSE))
  p[, Id := as.character(Id)]
  p[, model := m]
  p[, .(Id, model, PAlive, CET)]
}))
preds <- merge(preds, actual, by = "Id", all.x = TRUE)[is.na(actual), actual := 0L]
preds <- merge(preds, est[, .(Id, naive)], by = "Id", all.x = TRUE)

metrics <- rbind(
  preds[, .(model, pred = CET, actual)][, .(MAE = mae(pred, actual), RMSE = rmse(pred, actual),
                                            bias = mean(pred) - mean(actual)), by = model],
  preds[model == model[1], .(model = "naive_rate",
                             MAE = mae(naive, actual), RMSE = rmse(naive, actual),
                             bias = mean(naive) - mean(actual))]
)[order(MAE)]
print(metrics)

calib <- preds[model == "pnbd", decile_calibration(CET, actual)]
print(calib)

fwrite(metrics, "outputs/tables/03_holdout_metrics.csv")
fwrite(calib,   "outputs/tables/03_calibration_pnbd_deciles.csv")
saveRDS(preds,  "outputs/models/holdout_preds.rds")

# Seguimiento agregado: transacciones acumuladas reales vs. modelo
ggplot2::ggsave("outputs/figures/03_tracking_pnbd.png",
                plot(fits$pnbd, which = "tracking", cumulative = TRUE),
                width = 8, height = 4.5, dpi = 150)
cat("03 OK\n")
```

**Resultado de referencia (38.7 semanas de holdout):**

| Modelo | MAE | RMSE | Sesgo |
|---|---|---|---|
| Pareto/NBD | **0.751** | 1.597 | −0.099 |
| GGom/NBD | 0.751 | 1.597 | −0.099 |
| BG/NBD | 0.782 | 1.602 | −0.101 |
| Baseline ingenuo | 1.018 | 2.199 | +0.439 |

**Calibración del Pareto/NBD por deciles de CET:** el modelo **subestima** en los deciles bajos (decil 1: predice 0.108, observado 0.251; decil 6: 0.164 vs 0.343) y calibra bien arriba (decil 9: 1.308 vs 1.254; decil 10: 3.865 vs 3.737).

**Qué analizar (Q1–Q3):**
- Los BTYD reducen el MAE ~26% frente al baseline ingenuo (0.751 vs 1.018) y le quitan el sesgo positivo del baseline.
- **Tensión Q2:** el AIC en muestra prefiere BG/NBD; el MAE en holdout prefiere Pareto/NBD. La diferencia de MAE es pequeña (~4%) y viene de **un solo holdout sin intervalo de confianza**. No concluyas más de lo que sostienen los datos; la extensión de ventanas móviles (sección 11) es la forma correcta de profundizar.
- **El seguimiento agregado acumulado ajusta casi perfecto** (figura `03_tracking_pnbd.png`), pero eso esconde la subestimación en deciles bajos: un buen ajuste agregado no implica buena calibración individual. Muestra ambos gráficos juntos en el reporte.
- La subestimación en deciles bajos es un hallazgo: probablemente el supuesto de homogeneidad no captura bien a los clientes de baja actividad. Es una **hipótesis**, no un resultado; documéntala como tal.

### 6.4 Gasto, CLV y sensibilidad

```r
# archivo: R/04_spending_clv.R
source("R/00_utils.R")
suppressPackageStartupMessages({ library(CLVTools); library(data.table) })
ensure_dirs()

d    <- load_cdnow_clv()
fits <- readRDS("outputs/models/fits_cdnow.rds")

# --- Modelo de gasto Gamma/Gamma ----------------------------------------------
spend_fit <- gg(d$clv, verbose = FALSE)
print(summary(spend_fit))

# Supuesto clave del Gamma/Gamma: gasto medio independiente de la frecuencia
tx <- copy(d$tx)[, Date := lubridate::ymd(Date)]
split_date <- min(tx$Date) + EST_SPLIT_WEEKS * 7
cust <- tx[Date <= split_date, .(n = .N, mean_spend = mean(Price)), by = Id][n >= 2]
rho <- cor(cust$n, cust$mean_spend, method = "spearman")
cat(sprintf("Spearman(frecuencia, gasto medio) = %.3f  (Gamma/Gamma asume independencia; |rho| alto lo cuestiona)\n", rho))

# --- CLV a nivel cliente (horizonte 52 semanas, descuento 10% anual) ----------
clv_pred <- as.data.table(predict(fits$pnbd, predict.spending = spend_fit,
                                  prediction.end = 52,
                                  continuous.discount.factor = disc_per_unit(),
                                  verbose = FALSE))
print(head(clv_pred))
fwrite(clv_pred, "outputs/tables/04_clv_pnbd_52w.csv")

# --- Sensibilidad -------------------------------------------------------------
# OJO (comprobado al probar el código): predicted.CLV = DERT x gasto medio, con horizonte
# INFINITO. Por eso el CLV total depende de la tasa de descuento pero NO de prediction.end.
# El horizonte solo cambia CET y el gasto esperado del período (predicted.period.spending).
run_pred <- function(h = 52, a = DISCOUNT_ANNUAL)
  predict(fits$pnbd, predict.spending = spend_fit, prediction.end = h,
          continuous.discount.factor = disc_per_unit(a), verbose = FALSE)

sens_discount <- data.table(discount = c(0.05, 0.10, 0.15, 0.20))
sens_discount[, total_CLV := sapply(discount, function(a) sum(run_pred(a = a)$predicted.CLV))]
print(sens_discount)

sens_horizon <- data.table(horizon_weeks = c(13, 26, 52, 104))
sens_horizon[, total_period_spending := sapply(horizon_weeks,
               function(h) sum(run_pred(h = h)$predicted.period.spending))]
print(sens_horizon)

fwrite(sens_discount, "outputs/tables/04_sensitivity_discount.csv")
fwrite(sens_horizon,  "outputs/tables/04_sensitivity_horizon.csv")

# Concentración del valor: % del CLV total en el decil superior
setorder(clv_pred, -predicted.CLV)
top_share <- sum(head(clv_pred$predicted.CLV, ceiling(nrow(clv_pred) * 0.10))) / sum(clv_pred$predicted.CLV)
cat(sprintf("Decil superior concentra %.1f%% del CLV predicho\n", 100 * top_share))
cat("04 OK\n")
```

**Resultado de referencia:**
- Spearman(frecuencia, gasto medio) = 0.165: relación débil; el supuesto de independencia del Gamma/Gamma es razonable pero no perfecto. Repórtalo como limitación.
- El decil superior concentra **61.3%** del CLV predicho.
- CLV total según la tasa de descuento anual: 5% → 455,354; 10% → 317,281; 15% → 254,668; 20% → 217,210.
- Gasto esperado del período según el horizonte: 13 sem → 22,654; 26 → 42,309; 52 → 75,713; 104 → 128,544.

> **Trampa que descubrí al probarlo.** `predicted.CLV` es `DERT × gasto medio`, con horizonte **infinito**. Por eso el CLV total sale **idéntico** para horizontes de 26, 52 y 104 semanas: `prediction.end` solo cambia `CET` y el gasto del período. La sensibilidad al horizonte se mide con `predicted.period.spending`, no con el CLV. También: el manual nombra la columna `CLV`, pero en la salida real se llama `predicted.CLV`.

> **Otra trampa.** CLVTools usa una tasa de descuento **continua por unidad de tiempo**. Con unidad = semana hay que dividir entre 52 (`disc_per_unit()` lo hace). `prediction.end = 52` cuenta 52 semanas **desde el fin de la estimación**.

### 6.5 Benchmark justo contra XGBoost

El diseño importa más que el modelo. XGBoost necesita etiquetas futuras para entrenar, y las del holdout están prohibidas. Solución: **ventana deslizante con tasas**.

- **Entrenamiento:** variables con `wk ≤ 20`, objetivo en (20, 39].
- **Test (= el holdout de los BTYD):** variables con `wk ≤ 39`, objetivo después de 39.
- El objetivo se modela como **tasa semanal** y las variables son tasas y ratios, para que ventanas de distinto largo sean comparables.
- Un `stopifnot` y el test de `features_at` verifican que el entrenamiento no vea fechas posteriores.

```r
# archivo: R/05_benchmark_xgboost.R
source("R/00_utils.R"); source("R/features.R")
suppressPackageStartupMessages({ library(data.table); library(xgboost) })
ensure_dirs(); set.seed(SEED)

d  <- load_cdnow_clv()
tx <- copy(d$tx)[, Date := lubridate::ymd(Date)]
tx[, wk := as.numeric(difftime(Date, min(Date), units = "weeks"))]
tx[, Id := as.character(Id)]
END_WK <- max(tx$wk)

# --- Diseño temporal estricto --------------------------------------------------
# ENTRENAMIENTO: características con wk <= 20  ->  objetivo en (20, 39]
# TEST (= holdout de los modelos BTYD): características con wk <= 39 -> objetivo en (39, fin]
# El objetivo se modela como TASA semanal para que ventanas de distinto largo sean comparables.
T_TRAIN <- 20; H_TRAIN <- EST_SPLIT_WEEKS - T_TRAIN
T_TEST  <- EST_SPLIT_WEEKS; H_TEST <- END_WK - T_TEST

train <- make_set(tx, T_TRAIN, H_TRAIN)
test  <- make_set(tx, T_TEST,  H_TEST)
stopifnot("fuga temporal: el entrenamiento ve fechas del test" = max(tx[wk <= T_TRAIN]$wk) <= T_TRAIN)

params <- list(objective = "count:poisson", eta = 0.05, max_depth = 3,
               subsample = 0.8, colsample_bytree = 0.8, seed = SEED)
dtrain <- xgb.DMatrix(as.matrix(train[, ..FEATURE_COLS]), label = train$y_rate)
dtest  <- xgb.DMatrix(as.matrix(test[,  ..FEATURE_COLS]))
bst    <- xgb.train(params, dtrain, nrounds = 150, verbose = 0)
test[, xgb := predict(bst, dtest) * H_TEST]   # tasa -> nº esperado de transacciones

# --- Comparación en el MISMO holdout y los MISMOS clientes ---------------------
preds <- readRDS("outputs/models/holdout_preds.rds")
btyd  <- dcast(preds, Id + actual + naive ~ model, value.var = "CET")
cmp   <- merge(btyd, test[, .(Id, xgb)], by = "Id")

models <- intersect(c("pnbd", "bgnbd", "ggomnbd", "xgb", "naive"), names(cmp))
res <- rbindlist(lapply(models, function(m)
  data.table(model = m, MAE = mae(cmp[[m]], cmp$actual), RMSE = rmse(cmp[[m]], cmp$actual),
             bias = mean(cmp[[m]]) - mean(cmp$actual))))[order(MAE)]
print(res)
fwrite(res, "outputs/tables/05_benchmark.csv")
cat("05 OK (reporta el resultado aunque XGBoost gane o empate)\n")
```

**Resultado de referencia (mismo holdout, mismos 2,357 clientes):**

| Modelo | MAE | RMSE | Sesgo |
|---|---|---|---|
| Pareto/NBD | **0.751** | 1.597 | −0.099 |
| GGom/NBD | 0.751 | 1.597 | −0.099 |
| BG/NBD | 0.782 | 1.602 | −0.101 |
| XGBoost | 0.915 | 1.684 | **+0.012** |
| Baseline ingenuo | 1.018 | 2.199 | +0.439 |

**Qué analizar (Q4):**
- En este diseño XGBoost mejora al baseline ingenuo (MAE −10%) pero **queda 22% peor que el Pareto/NBD**. Su sesgo es casi nulo (+0.012) mientras que los BTYD subestiman en promedio (−0.10).
- **No generalices:** con hiperparámetros fijos, ventanas de entrenamiento desiguales y un solo holdout, esto muestra que el marco probabilístico es competitivo con pocos parámetros, no que siempre gane. Si XGBoost ganara en tu corrida, repórtalo igual.

**Limitación que debes escribir en el reporte:** las ventanas de entrenamiento y test no tienen el mismo largo (19 vs ~39 semanas), y se normalizan a tasas; es una aproximación razonable, no una equivalencia exacta. XGBoost va con hiperparámetros fijos (sin tuning exhaustivo) porque el objetivo es un baseline justo, no ganar.

### 6.6 Covariables estáticas y dinámicas

> **Hallazgo al probarlo:** con `estimation.split = 40` el Pareto/NBD base **no converge** en `apparel` (coeficientes `NA`). Con 52, 104 o 156 semanas sí. El script usa 104. Si te pasa en datos propios, prueba una ventana mayor, otros valores iniciales o `optimx.args = list(method = "Nelder-Mead")`.

```r
# archivo: R/06_covariates.R
source("R/00_utils.R")
suppressPackageStartupMessages({ library(CLVTools); library(data.table) })
ensure_dirs()

# ATENCIÓN: los covariables de apparel son SIMULADOS. Sirven para aprender la mecánica
# del modelo, no como evidencia de efectos reales.
data("apparelTrans",     package = "CLVTools")
data("apparelStaticCov", package = "CLVTools")
data("apparelDynCov",    package = "CLVTools")

# Nota (comprobada): con estimation.split = 40 el Pareto/NBD base NO converge en apparel
# (coeficientes NA). Con 52, 104 o 156 semanas sí. Usamos 104.
SPLIT_APP <- 104
clv_app <- clvdata(apparelTrans, date.format = "ymd", time.unit = TIME_UNIT,
                   estimation.split = SPLIT_APP,
                   name.id = "Id", name.date = "Date", name.price = "Price")

# --- (a) Sin covariables ----------------------------------------------------------
fit_base <- pnbd(clv_app, verbose = FALSE)

# --- (b) Covariables estáticas (Gender, Channel) en compra y abandono -------------
clv_static <- SetStaticCovariates(clv_app,
  data.cov.life  = apparelStaticCov, names.cov.life  = c("Gender", "Channel"),
  data.cov.trans = apparelStaticCov, names.cov.trans = c("Gender", "Channel"),
  name.id = "Id")
fit_static <- pnbd(clv_static, verbose = FALSE)

# --- (c) Covariables dinámicas (High.Season, Gender, Channel) ---------------------
clv_dyn <- SetDynamicCovariates(clv_app,
  data.cov.life  = apparelDynCov, names.cov.life  = c("High.Season", "Gender", "Channel"),
  data.cov.trans = apparelDynCov, names.cov.trans = c("High.Season", "Gender", "Channel"),
  name.id = "Id", name.date = "Cov.Date")
fit_dyn <- pnbd(clv_dyn, verbose = FALSE)

cands <- list(base = fit_base, static = fit_static, dynamic = fit_dyn)

# --- Ajuste en muestra + error en holdout -----------------------------------------
tx <- as.data.table(apparelTrans)[, Date := as.Date(Date)]
split_date <- min(tx$Date) + SPLIT_APP * 7
actual <- tx[Date > split_date, .(actual = .N), by = Id][, Id := as.character(Id)]

holdout_mae <- function(f) {
  p <- as.data.table(predict(f, predict.spending = FALSE, verbose = FALSE))[, Id := as.character(Id)]
  p <- merge(p, actual, by = "Id", all.x = TRUE)[is.na(actual), actual := 0L]
  mae(p$CET, p$actual)
}

cmp <- rbindlist(lapply(names(cands), function(m) {
  f <- cands[[m]]
  data.table(model = m, logLik = as.numeric(logLik(f)), AIC = AIC(f), BIC = BIC(f),
             holdout_MAE = tryCatch(holdout_mae(f), error = function(e) NA_real_))
}))[order(AIC)]
print(cmp)
fwrite(cmp, "outputs/tables/06_covariates_comparison.csv")

# Test de razón de verosimilitud (anidados, mismos datos)
print(tryCatch(lrtest(fit_static, fit_base), error = function(e) conditionMessage(e)))
cat("06 OK\n")
```

**Resultado de referencia (covariables simuladas):**

| Modelo | AIC | holdout MAE |
|---|---|---|
| Dinámico | **11,525.9** | **1.858** |
| Estático | 11,658.1 | 2.007 |
| Base | 11,704.2 | 2.040 |

El test de razón de verosimilitud estático vs. base da p ≈ 5×10⁻¹¹. **No lo interpretes como efecto real:** los covariables están simulados, así que esto solo valida que entiendes el mecanismo. Solo el Pareto/NBD admite covariables dinámicas.

### 6.7 Estudio de simulación: recuperación de parámetros

```r
# archivo: R/07_simulation_recovery.R
source("R/00_utils.R"); source("R/simulate.R")
suppressPackageStartupMessages({ library(CLVTools); library(data.table) })
ensure_dirs()

truth <- list(r = 0.553, alpha = 10.578, s = 0.606, beta = 11.669)
tx <- simulate_pnbd(n = 3000, r = truth$r, alpha = truth$alpha, s = truth$s, beta = truth$beta)
validate_transactions(tx)

clv <- clvdata(tx, date.format = "ymd", time.unit = TIME_UNIT, estimation.split = EST_SPLIT_WEEKS,
               name.id = "Id", name.date = "Date", name.price = "Price")
fit <- pnbd(clv, verbose = FALSE)
est <- coef(fit)

out <- data.table(param = c("r", "alpha", "s", "beta", "E[lambda]=r/alpha", "E[mu]=s/beta"),
                  truth = c(truth$r, truth$alpha, truth$s, truth$beta,
                            truth$r / truth$alpha, truth$s / truth$beta),
                  estimate = c(est[["r"]], est[["alpha"]], est[["s"]], est[["beta"]],
                               est[["r"]] / est[["alpha"]], est[["s"]] / est[["beta"]]))
out[, rel_error := (estimate - truth) / truth]
print(out)
fwrite(out, "outputs/tables/07_parameter_recovery.csv")
cat("07 OK: los parámetros individuales (alpha, beta) están débilmente identificados;\n",
    "   las medias implícitas E[lambda], E[mu] son la comparación fiable.\n")
```

**Resultado de referencia (3,000 clientes):**

| Parámetro | Verdadero | Estimado | Error relativo |
|---|---|---|---|
| r | 0.553 | 0.543 | −1.9% |
| alpha | 10.578 | 10.264 | −3.0% |
| s | 0.606 | 0.516 | −14.9% |
| beta | 11.669 | 9.735 | −16.6% |
| **E[λ] = r/alpha** | 0.0523 | 0.0529 | **+1.1%** |
| **E[μ] = s/beta** | 0.0519 | 0.0530 | **+2.0%** |

**Lectura:** los parámetros de abandono (`s`, `beta`) se recuperan peor porque están débilmente identificados y correlacionados entre sí; las **medias implícitas** sí se recuperan con error ~1–2%. Esa es la comparación fiable, y es una buena idea para contarla en una entrevista.

### 6.8 Orquestador

```r
# archivo: R/run_all.R
# Ejecuta el pipeline completo desde una clonación limpia:
#   renv::restore(); Rscript R/run_all.R
scripts <- c("R/01_load_validate.R", "R/02_fit_models.R", "R/03_holdout_validation.R",
             "R/04_spending_clv.R", "R/05_benchmark_xgboost.R",
             "R/06_covariates.R", "R/07_simulation_recovery.R")
for (s in scripts) {
  cat("\n=====", s, "=====\n")
  t0 <- Sys.time()
  source(s, local = new.env())
  cat(sprintf("(%.1f s)\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
```

## 7. Tests y CI

Los 20 tests pasaron en mi entorno. Cubren las métricas, la validación de datos, **la ausencia de fuga temporal en `features_at`** y la reproducibilidad del simulador.

```r
# archivo: tests/testthat/test-metrics.R
source("../../R/00_utils.R")

test_that("mae y rmse calculan lo esperado", {
  expect_equal(mae(c(1, 2, 3), c(1, 3, 5)), 1)
  expect_equal(rmse(c(0, 0), c(3, 4)), sqrt(12.5))
})

test_that("decile_calibration reparte en n bins y respeta el orden", {
  set.seed(1)
  p <- runif(1000); a <- rpois(1000, p)
  cal <- decile_calibration(p, a, n = 10)
  expect_equal(nrow(cal), 10)
  expect_equal(sum(cal$n), 1000)
  expect_true(all(diff(cal$mean_pred) >= 0))
})

test_that("el descuento por unidad es el continuo anual dividido entre las unidades", {
  expect_equal(disc_per_unit(0.10, 52), log(1.10) / 52)
  expect_lt(disc_per_unit(0.10, 52), disc_per_unit(0.10, 1))
})
```

```r
# archivo: tests/testthat/test-data.R
source("../../R/00_utils.R")
source("../../R/features.R")

ok <- data.table(Id = c("a", "a", "b"), Date = as.Date("2020-01-01") + c(0, 7, 3), Price = c(10, 12, 5))

test_that("validate_transactions acepta datos válidos y rechaza inválidos", {
  expect_true(validate_transactions(ok))
  expect_error(validate_transactions(ok[, .(Id, Date)]))
  bad <- copy(ok); bad[1, Price := NA]
  expect_error(validate_transactions(bad))
  neg <- copy(ok); neg[1, Price := -1]
  expect_error(validate_transactions(neg))
})

test_that("features_at NO usa transacciones posteriores a t1 (sin fuga temporal)", {
  tx <- data.table(Id = c("a", "a", "a", "b"), Price = c(10, 10, 999, 5), wk = c(0, 5, 30, 2))
  f <- features_at(tx, t1 = 10)
  expect_equal(f[Id == "a", n], 2)                  # la compra de la semana 30 queda fuera
  expect_equal(f[Id == "a", total_spend], 20)       # el gasto 999 no entra
  y <- target_in(tx, t1 = 10, H = 30)
  expect_equal(y[Id == "a", y], 1)                  # y SÍ cuenta en el objetivo
})
```

```r
# archivo: tests/testthat/test-simulation.R
source("../../R/00_utils.R")
source("../../R/simulate.R")

test_that("simulate_pnbd es reproducible y respeta el formato esperado", {
  a <- simulate_pnbd(n = 200, seed = 7)
  b <- simulate_pnbd(n = 200, seed = 7)
  expect_identical(a, b)
  expect_true(all(c("Id", "Date", "Price") %in% names(a)))
  expect_true(validate_transactions(a))
  expect_equal(uniqueN(a$Id) <= 200, TRUE)
})

test_that("la primera compra de cada cliente existe y no hay fechas fuera de la ventana", {
  a <- simulate_pnbd(n = 300, t_end = 78, seed = 3)
  expect_lte(as.numeric(max(a$Date) - as.Date("2000-01-03")) / 7, 78.5)
  expect_equal(uniqueN(a$Id), 300)
})
```

**CI (GitHub Actions).** No lo ejecuté; es el patrón estándar de `r-lib/actions`. Verifica la primera corrida y ajusta si hace falta.

```yaml
# archivo: .github/workflows/ci.yml
name: ci
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: r-lib/actions/setup-r@v2
        with:
          use-public-rspm: true
      - name: Dependencias del sistema (CLVTools compila contra GSL)
        run: sudo apt-get update && sudo apt-get install -y libgsl-dev
      - uses: r-lib/actions/setup-renv@v2
      - name: Tests
        run: Rscript -e 'testthat::test_dir("tests/testthat", stop_on_failure = TRUE)'
```

## 8. Reporte (`reports/p7_clv.qmd`)

Estructura obligatoria, en este orden:

1. **Resumen ejecutivo** (≤ 150 palabras, bullets): la pregunta, qué modelo funcionó mejor y por qué importa.
2. **Datos y diseño temporal:** diagrama simple de estimación/holdout; por qué esto evita la fuga.
3. **Modelos:** una frase de intuición, la fórmula y los supuestos de Pareto/NBD y BG/NBD (tres niveles: intuición → modelo formal → aplicación).
4. **Resultados:** tablas de las secciones 6.2–6.5; gráfico de seguimiento; calibración por deciles; benchmark.
5. **Sensibilidad y concentración de valor:** descuento, horizonte, top decil.
6. **Simulación:** tabla de recuperación y lectura.
7. **Limitaciones:** supuestos violados, holdout único, ventanas desiguales en el benchmark, covariables simuladas, solo contextos sin contrato.
8. **Reproducibilidad:** cómo correrlo, versiones, `renv.lock`.

Figuras mínimas: `01_tracking`, `01_frequency`, `03_tracking_pnbd`, calibración por deciles (a partir de `03_calibration_pnbd_deciles.csv`), benchmark de MAE.

## 9. Criterios de aceptación (definición de terminado)

- [ ] **A1 Reproducible:** desde un clon limpio, `renv::restore()` y `Rscript R/run_all.R` terminan sin errores.
- [ ] **A2 Sin fuga temporal:** el test de `features_at` pasa y el `stopifnot` del paso 5 está activo.
- [ ] **A3 Comparación completa:** ≥ 3 modelos con logLik/AIC/BIC y MAE/RMSE/sesgo en holdout, más el baseline ingenuo.
- [ ] **A4 Calibración:** tabla por deciles y gráfico de seguimiento agregado.
- [ ] **A5 Benchmark honesto:** XGBoost reportado **aunque gane o empate**; limitaciones del diseño escritas.
- [ ] **A6 Simulación:** tabla de recuperación con la lectura sobre identificabilidad.
- [ ] **A7 Tests y CI:** todos los tests en verde en local y en GitHub Actions.
- [ ] **A8 Reporte y README:** reporte renderizado; README con resultados, limitaciones y comandos.
- [ ] **A9 Trazabilidad:** `docs/decisiones.md` con cada cambio de parámetro y su motivo.

## 10. Trampas metodológicas y decisiones de diseño (resumen)

1. **Horizonte vs. CLV:** el CLV es de horizonte infinito; solo el descuento lo mueve.
2. **Unidad de descuento:** tasa continua por unidad de tiempo; dividir entre 52 con semanas.
3. **Ventana de estimación:** con 40 semanas el Pareto/NBD de apparel no converge; 104 sí.
4. **GGom/NBD degenerado:** en CDNOW colapsa al Pareto/NBD.
5. **AIC ≠ holdout:** pueden elegir modelos distintos; reporta ambos.
6. **Covariables simulados:** no extraigas conclusiones de negocio.
7. **Fuga temporal:** nunca construyas variables con datos posteriores al corte; escala o imputa solo con información del entrenamiento.
8. **Un solo holdout:** sin intervalos; las diferencias pequeñas no son concluyentes.
9. **Supuesto Gamma/Gamma:** verifica la relación frecuencia–gasto (Spearman) y repórtala.
10. **Solo contextos sin contrato:** no apliques esto a suscripciones ni préstamos.

## 11. Extensiones (para subir a semi-senior alto)

- **Ventanas móviles (rolling origin):** repite el holdout en varios cortes y reporta media y dispersión del MAE por modelo.
- **Incertidumbre:** `predict(..., uncertainty = "boots", level = 0.9)` para intervalos de CET/CLV.
- **Pipeline con `targets`** y caché de modelos.
- **Dashboard** en Shiny con CLV por cliente y filtros.
- **Datos reales (Fase B):** repite el pipeline con un dataset propio y compara con CDNOW.
- **Puente a crédito de consumo/fintech:** aplicar el mismo marco a actividad de comercios sobre datos sintéticos de BNPL (por ejemplo, los de P13) para estimar actividad futura y probabilidad de abandono de comercios.

## 12. Cronograma [ESTIMADO]

| Fase | Contenido | Horas |
|---|---|---|
| 1 | Entorno, renv, utilidades, EDA (6.0–6.1) | 5 |
| 2 | Ajuste y comparación (6.2) | 6 |
| 3 | Holdout, calibración, baseline (6.3) | 6 |
| 4 | Gasto, CLV, sensibilidad (6.4) | 6 |
| 5 | Benchmark XGBoost con diseño temporal (6.5) | 8 |
| 6 | Covariables (6.6) | 5 |
| 7 | Simulación (6.7) | 4 |
| 8 | Tests y CI (7) | 3 |
| 9 | Reporte y README (8) | 6 |
| | **Total** | **≈ 49 h** |

## 13. Cómo contarlo en una entrevista y qué valor tiene para crédito

**Tres frases:** (1) "Validé fuera de tiempo contra un baseline ingenuo y contra un XGBoost con diseño temporal justo." (2) "Hice un estudio de simulación y vi que los parámetros de abandono están débilmente identificados, pero sus medias implícitas se recuperan." (3) "Encontré que el CLV es de horizonte infinito y que mi análisis de sensibilidad al horizonte era inválido hasta que lo probé."

**Relevancia para crédito (juicio mío):** el proyecto es de analítica de marketing. La transferencia directa a crédito corporativo o private credit es limitada. Su valor está en la señal de modelado probabilístico con validación temporal rigurosa, y se acerca a crédito de consumo y fintech (engagement de tarjeta, actividad de comercios, unit economics LTV/CAC). Si tu prioridad es crédito, construye antes los proyectos P1 y P14 y deja este como complemento.

## 14. Qué está verificado y qué no

| Elemento | Estado |
|---|---|
| `00_utils`, `features`, `simulate` y los 20 tests | ✅ Ejecutados, 20/20 en verde |
| Scripts `01`, `02`, `03`, `04`, `06`, `07` | ✅ Ejecutados de punta a punta |
| Script `05` (XGBoost) | ✅ Ejecutado (xgboost 3.2.1.1) |
| `run_all.R` | ✅ Ejecutado de punta a punta desde una carpeta `outputs/` vacía: código de salida 0, ~84 s |
| `ci.yml`, `renv`, Quarto, Docker | ❌ No ejecutados |
| Firmas de `SetStaticCovariates` / `SetDynamicCovariates` | ✅ Funcionaron con los argumentos del script (el manual en línea las tenía truncadas) |
| Online Retail II (UCI) | ❌ No verificado |

Hechos de CLVTools respaldados por la documentación oficial: versión 0.12.1 y licencia GPL-3 en CRAN; modelos incluidos; covariables dinámicas solo en Pareto/NBD; modelo de gasto Gamma/Gamma; argumentos de `predict()` (`prediction.end`, `predict.spending`, `continuous.discount.factor`, `uncertainty`).

## 15. Prompt para tu asistente de código (Cursor / Claude Code)

```text
Implementa el proyecto descrito en P7_CLVTools_Especificacion.md, fase por fase (secciones 5 a 9).
Reglas:
1. Crea la estructura de la sección 5 y copia el código de la sección 6 SIN modificar su lógica.
2. Después de cada fase ejecuta los scripts y los tests; si algo falla, corrígelo y anota la causa
   y el cambio en docs/decisiones.md.
3. No inventes resultados: toda cifra del README y del reporte debe salir de outputs/tables/*.csv
   generados por tu corrida. Si difieren de los "resultados de referencia", explícalo.
4. No cambies parámetros de R/00_utils.R sin registrarlo en docs/decisiones.md.
5. No marques un criterio de aceptación (sección 9) sin evidencia ejecutada.
6. Escribe el reporte Quarto siguiendo la sección 8 y las limitaciones de las secciones 6 y 10.
Al terminar, entrega un resumen de qué criterios A1-A9 se cumplen y cuáles no, con evidencia.
```

---

## Fuentes

- CRAN, *CLVTools: Tools for Customer Lifetime Value Estimation* (v0.12.1, GPL-3): https://cloud.r-project.org/web/packages/CLVTools/index.html
- Manual de referencia de CLVTools (firmas de `clvdata`, `pnbd`, `bgnbd`, `ggomnbd`, `gg`, `predict`): https://cran.r-universe.dev/CLVTools/doc/manual.html
- Repositorio de CLVTools: https://github.com/bachmannpatrick/CLVTools
- Bachmann, Meierer y Näf (2021), *The Role of Time-Varying Contextual Factors in Latent Attrition Models for Customer Base Analysis*, Marketing Science 40(4), 783–809: https://econpapers.repec.org/RePEc:inm:ormksc:v:40:y:2021:i:4:p:783-809
- Referencias de modelos citadas por el paquete: Schmittlein, Morrison y Colombo (1987) para el Pareto/NBD; Fader, Hardie y Lee (2005) para el BG/NBD; Bemmaor y Glady (2012) para el Gamma-Gompertz/NBD.
