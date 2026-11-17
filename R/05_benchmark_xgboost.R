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
