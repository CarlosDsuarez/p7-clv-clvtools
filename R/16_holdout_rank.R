# archivo: R/16_holdout_rank.R
# Hipótesis fijada antes de mirar el resultado:
# en el holdout de 39 semanas de la cohorte de Online Retail (la de R/10),
# el Spearman y la captura del decil superior del Pareto/NBD y del BG/NBD
# superan a la tasa histórica.
# El xlsx no se versiona.
source("R/00_utils.R")
source("R/retail_prepare.R")
source("R/rank_metrics.R")
suppressPackageStartupMessages({
  library(CLVTools)
  library(data.table)
  library(ggplot2)
  library(readxl)
})
ensure_dirs()
set.seed(SEED)

raw_path <- "data/raw/online_retail_II.xlsx"
stopifnot("falta data/raw/online_retail_II.xlsx" = file.exists(raw_path))
raw <- rbindlist(lapply(excel_sheets(raw_path), function(s) {
  as.data.table(read_excel(raw_path, sheet = s))
}), fill = TRUE)
prep <- prepare_retail_transactions(
  raw, first_weeks = 13, split_weeks = EST_SPLIT_WEEKS, horizon_weeks = 39
)
tx <- copy(prep$tx)
dated <- copy(tx)
origin <- min(dated$Date)
split_date <- origin + EST_SPLIT_WEEKS * 7
actual <- dated[Date > split_date, .(actual = .N), by = Id]
actual[, Id := as.character(Id)]
est <- dated[Date <= split_date, .(
  n = .N,
  first_wk = as.numeric(difftime(min(Date), origin, units = "weeks"))
), by = Id]
H <- as.numeric(difftime(max(dated$Date), split_date, units = "weeks"))
est[, naive := (n - 1) / pmax(EST_SPLIT_WEEKS - first_wk, 1e-6) * H]
est[, Id := as.character(Id)]

clv_tx <- copy(tx)
clv_tx[, Date := format(Date, "%Y-%m-%d")]
validate_transactions(clv_tx)
clv <- clvdata(clv_tx, date.format = "ymd", time.unit = TIME_UNIT,
               estimation.split = EST_SPLIT_WEEKS,
               name.id = "Id", name.date = "Date", name.price = "Price")
fit_safe <- function(expr) tryCatch(expr, error = function(e) {
  message("Ajuste fallido: ", conditionMessage(e)); NULL })
fits <- Filter(Negate(is.null), list(
  pnbd = fit_safe(pnbd(clv, verbose = FALSE)),
  bgnbd = fit_safe(bgnbd(clv, verbose = FALSE)),
  ggomnbd = fit_safe(ggomnbd(clv, verbose = FALSE))
))

preds <- rbindlist(lapply(names(fits), function(m) {
  p <- as.data.table(predict(fits[[m]], predict.spending = FALSE, verbose = FALSE))
  p[, .(Id = as.character(Id), model = m, pred = CET)]
}))
preds <- merge(preds, actual, by = "Id", all.x = TRUE)[is.na(actual), actual := 0]
preds <- merge(preds, est[, .(Id, naive)], by = "Id", all.x = TRUE)

score <- function(model, pred, actual) {
  data.table(
    model = model,
    spearman = safe_spearman(pred, actual),
    top_decile_share = top_decile_capture(pred, actual),
    MAE = mae(pred, actual),
    n = length(actual)
  )
}

metrics <- rbindlist(lapply(names(fits), function(m) {
  p <- preds[model == m]
  score(m, p$pred, p$actual)
}))
naive_rows <- preds[model == names(fits)[1]]
metrics <- rbind(metrics, score("naive_rate", naive_rows$naive, naive_rows$actual))
setorder(metrics, -spearman)
print(metrics)
fwrite(metrics, "outputs/tables/16_holdout_rank.csv")

p <- ggplot(metrics, aes(reorder(model, top_decile_share), top_decile_share)) +
  geom_col(fill = "gray35") +
  scale_y_continuous(labels = function(x) paste0(round(100 * x), "%")) +
  labs(x = NULL, y = "Parte de las compras del holdout en el decil superior",
       title = "Holdout de 39 semanas, Online Retail II") +
  theme_bw()
ggsave("outputs/figures/16_holdout_rank.png", p, width = 8, height = 4.5, dpi = 150)
cat("16 OK\n")
