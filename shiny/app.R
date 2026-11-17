# Tablero de CLV por cliente. No reajusta modelos: lee las tablas del pipeline.
#   shiny::runApp("shiny")
library(shiny)
library(data.table)
library(ggplot2)
library(DT)

filter_src <- if (file.exists("R/dashboard_filter.R")) {
  "R/dashboard_filter.R"
} else {
  "../R/dashboard_filter.R"
}
source(filter_src)

table_path <- function(file) {
  candidates <- c(
    file.path("outputs", "tables", file),
    file.path("..", "outputs", "tables", file)
  )
  hit <- candidates[file.exists(candidates)]
  if (length(hit) == 0) {
    stop("Falta outputs/tables/", file, ". Corre antes R/04_spending_clv.R y R/09_uncertainty.R.")
  }
  hit[[1]]
}

customers <- fread(table_path("04_clv_pnbd_52w.csv"))
intervals <- fread(table_path("09_clv_intervals.csv"))
customers[, Id := as.character(Id)]
intervals[, Id := as.character(Id)]
customers <- merge(
  customers,
  intervals[, .(Id, predicted.CLV.CI.5, predicted.CLV.CI.95)],
  by = "Id"
)
setorder(customers, -predicted.CLV)
total_clv <- sum(customers$predicted.CLV)
clv_ceiling <- ceiling(max(customers$predicted.CLV))

ui <- fluidPage(
  titlePanel("CLV por cliente"),
  tags$p(
    "Pareto/NBD y Gamma/Gamma sobre CDNOW. El CLV es de horizonte infinito ",
    "con descuento anual del 10%. Las compras esperadas son a 52 semanas ",
    "desde el fin de la estimación. El intervalo al 90% es de esa media, ",
    "no de la próxima compra."
  ),
  sidebarLayout(
    sidebarPanel(
      sliderInput("palive", "P(activo) mínima", min = 0, max = 1, value = 0, step = 0.01),
      sliderInput("clv_min", "CLV mínimo", min = 0, max = clv_ceiling, value = 0, step = 1),
      textInput("id_q", "Id contiene", value = ""),
      width = 3
    ),
    mainPanel(
      fluidRow(
        column(4, tags$h3("Clientes", style = "margin-top: 0; font-size: 1rem;"), textOutput("n_lab")),
        column(4, tags$h3("CLV del filtro", style = "margin-top: 0; font-size: 1rem;"), textOutput("sum_lab")),
        column(4, tags$h3("Parte del total", style = "margin-top: 0; font-size: 1rem;"), textOutput("share_lab"))
      ),
      plotOutput("top_plot", height = "380px"),
      DTOutput("tbl")
    )
  )
)

server <- function(input, output, session) {
  shown <- reactive({
    filter_customers(customers, input$palive, input$clv_min, input$id_q)
  })

  output$n_lab <- renderText(format(nrow(shown()), big.mark = ","))
  output$sum_lab <- renderText(format(round(sum(shown()$predicted.CLV)), big.mark = ","))
  output$share_lab <- renderText({
    sprintf("%.1f%%", 100 * sum(shown()$predicted.CLV) / total_clv)
  })

  output$top_plot <- renderPlot({
    x <- shown()
    validate(need(nrow(x) > 0, "Ningún cliente pasa el filtro."))
    top <- head(x, 15)
    ggplot(top, aes(reorder(Id, predicted.CLV), predicted.CLV)) +
      geom_col(fill = "gray35") +
      coord_flip() +
      labs(x = NULL, y = "CLV", title = "15 clientes de mayor CLV en el filtro") +
      theme_bw()
  })

  output$tbl <- renderDT({
    x <- shown()
    view <- data.table(
      Id = x$Id,
      `P(activo)` = round(x$PAlive, 3),
      `Compras en 52 sem.` = round(x$CET, 3),
      `Gasto medio` = round(x$predicted.mean.spending, 2),
      CLV = round(x$predicted.CLV, 2),
      `CLV 5%` = round(x$predicted.CLV.CI.5, 2),
      `CLV 95%` = round(x$predicted.CLV.CI.95, 2)
    )
    datatable(
      view,
      rownames = FALSE,
      caption = "Clientes que pasan el filtro, ordenados por CLV.",
      options = list(pageLength = 10, searching = FALSE, dom = "tip")
    )
  })
}

shinyApp(ui, server)
