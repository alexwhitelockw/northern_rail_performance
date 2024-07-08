library(data.table)
library(ggplot2)
library(leaflet)
library(RSQLite)
library(scales)
library(shiny)
library(stringr)

function(input, output, session) {
  conn <-
    DBI::dbConnect(SQLite(),
                   "database/northern_rail_performance.db")
  
  # Service Performance Data ----------
  # Baseline Table used for plots and value boxes
  service_quality <- DBI::dbGetQuery(
    conn = conn,
    "WITH PERIOD_PERFORMANCE AS (
        SELECT COMPONENT,
               AREA,
               DATE AS PERIOD_DATE_RANGE,
               IIF(
                LENGTH(DATE) = 21,
                DATE(20 || SUBSTR(DATE, 9, 2) || '-' || SUBSTR(DATE, 4, 2) || '-' || SUBSTR(DATE, 1, 2)),
                DATE(20 || SUBSTR(DATE, 7, 2) || '-' || SUBSTR(DATE, 4, 2) || '-' || SUBSTR(DATE, 1, 2))
                ) AS PERIOD_START_DATE,
                CAST(REPLACE(PERFORMANCE, '%', '') AS FLOAT) AS PERFORMANCE_PRCNT
        FROM SERVICE_QUALITY
        )

        SELECT *,
               PERFORMANCE_PRCNT - LAG(PERFORMANCE_PRCNT) OVER
                    (PARTITION BY COMPONENT, AREA
                     ORDER BY PERIOD_START_DATE) AS PERFORMANCE_CHNG,
               AVG(PERFORMANCE_PRCNT) OVER (
                    PARTITION BY COMPONENT, AREA
                    ORDER BY PERIOD_START_DATE
                    ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS AVG_PERFORMANCE_PRCNT
        FROM PERIOD_PERFORMANCE;"
  )
  
  # Value Boxes -----------------------
  # Average performance with for a component within the current year
  output$customer_service_performance <- renderText({
    service_quality <- as.data.table(service_quality)
    customer_service_performance <-
      service_quality[COMPONENT == "Customer Service" &
                        year(PERIOD_START_DATE) == year(Sys.Date()),
                      .(mean_performance = mean(PERFORMANCE_PRCNT))]
    paste0(round(customer_service_performance$mean_performance, 0),
           "%")
  })
  
  output$station_service_performance <- renderText({
    service_quality <- as.data.table(service_quality)
    customer_service_performance <-
      service_quality[COMPONENT == "Station" &
                        year(PERIOD_START_DATE) == year(Sys.Date()),
                      .(mean_performance = mean(PERFORMANCE_PRCNT))]
    paste0(round(customer_service_performance$mean_performance, 0),
           "%")
  })
  
  output$train_service_performance <- renderText({
    service_quality <- as.data.table(service_quality)
    customer_service_performance <-
      service_quality[COMPONENT == "Trains" &
                        year(PERIOD_START_DATE) == year(Sys.Date()),
                      .(mean_performance = mean(PERFORMANCE_PRCNT))]
    paste0(round(customer_service_performance$mean_performance, 0),
           "%")
  })
  
  # Plot for Service Performance by Period ------
  output$service_performance <- renderPlot({
    ggplot(service_quality) +
      geom_line(
        aes(
          x = as.Date(PERIOD_START_DATE),
          y = AVG_PERFORMANCE_PRCNT,
          group = AREA,
          colour = AREA
        ),
        linejoin = "round",
        lineend = "round",
        linemitre = 2,
        linewidth = .7
      ) +
      facet_wrap(~ COMPONENT, ncol = 1) +
      scale_colour_brewer(type = "qual",
                          palette = "Dark2") +
      scale_y_continuous(labels = percent_format(scale = 1),
                         breaks = seq.int(10, 100, 20)) +
      theme_minimal(base_size = 16) +
      theme(legend.position = "bottom") +
      labs(x = NULL,
           y = NULL,
           colour = NULL)
    
  })
  
  # Plot for End of Year Performance ------------
  output$eoy_performance <- renderPlot({
    eoy_performance <- DBI::dbGetQuery(
      conn = conn,
      "WITH EOY_PERFORMANCE AS (
        SELECT COMPONENT,
               REPLACE(REPLACE(REPLACE(AREA, 'Customer Service', ''), 'Station', ''), 'Train', '') AS AREA,
               SUBSTRING(YEAR, INSTR(YEAR, 2), 4) AS YEAR,
               CAST(REPLACE(PERFORMANCE, '%', '') AS FLOAT) AS PERFORMANCE_PRCNT
        FROM EOY_SERVICE_QUALITY
      )

      SELECT *,
             PERFORMANCE_PRCNT - LAG(PERFORMANCE_PRCNT, 1) OVER (PARTITION BY AREA ORDER BY YEAR) AS YOY_CHANGE
      FROM EOY_PERFORMANCE;"
    )
    
    eoy_performance |>
      ggplot(aes(
        x = AREA,
        y = PERFORMANCE_PRCNT,
        colour = YEAR,
        fill = YEAR
      )) +
      geom_col(position = position_dodge2(preserve = "single")) +
      coord_flip() +
      scale_y_continuous(labels = percent_format(scale = 1)) +
      scale_colour_brewer(palette = 2) +
      scale_fill_brewer(palette = 2) +
      facet_wrap(~ COMPONENT, scales = "free_y", ncol = 1) +
      theme_minimal(base_size = 16) +
      theme(legend.position = "bottom") +
      labs(
        x = NULL,
        y = NULL,
        colour = NULL,
        fill = NULL
      )
  })
  
  # Overall Delay Performance ---------
  
  overall_delay_performance <-
    DBI::dbGetQuery(conn = conn,
                    "SELECT DISTINCT * FROM ON_TIME_DATA;") |>
    as.data.table()
  
  overall_delay_performance[, start_date := str_remove(start_date, "th")]
  overall_delay_performance[, start_date := as.Date(start_date, "%d %B %Y")]
  
  overall_delay_performance <-
    overall_delay_performance[year(start_date) == year(Sys.Date())]
  
  output$overall_delay_early <-
    renderText({
      paste0(round(mean(
        as.numeric(overall_delay_performance$Early)
      ), 0), "%")
    })
  
  output$overall_delay_ontime <-
    renderText({
      paste0(round(mean(
        as.numeric(overall_delay_performance$`On Time`)
      ), 0), "%")
    })
  
  output$overall_delay_15mins <-
    renderText({
      paste0(round(mean(
        as.numeric(overall_delay_performance$`Within 15 mins`)
      ), 0), "%")
    })
  
  output$overall_delay_cancelled <-
    renderText({
      paste0(round(mean(
        as.numeric(overall_delay_performance$Cancelled)
      ), 0), "%")
    })
  
  # Plot locations of Delays ----------
  
  output$delay_locations <- renderLeaflet({
    delay_reasons <-
      DBI::dbGetQuery(conn = conn,
                      "SELECT * FROM DELAY_REASONS_GEOCODE;") |>
      as.data.table()
    
    leaflet(delay_reasons) |>
      addProviderTiles(providers$Stadia.StamenTonerLite) |>
      addCircleMarkers(popup = ~ delay_location,
                       color = "#038C8C")
  })
  
  # Service Group Performance ---------
  output$service_group_delay_performance <- renderPlot({
    service_group_performance <-
      DBI::dbGetQuery(conn = conn,
                      "SELECT * FROM SERVICE_GROUP_PERFORMANCE;") |>
      as.data.table()
    
    service_group_performance[, report_end_date := as.Date(report_end_date, "%d %B %Y")]
    
    service_group_performance <- service_group_performance |>
      melt(
        id.vars = c("Service Group", "report_end_date"),
        measure.vars = c("All Cancellations",
                         "On Time",
                         "Time to 15")
      )
    
    service_group_performance[, value := as.numeric(str_remove(value, "%"))]
    
    service_group_performance[, .(value = mean(value)), by = c("Service Group", "variable")] |>
      ggplot(aes(x = `Service Group`, y = value, group = `Service Group`)) +
      geom_col(
        alpha = .8,
        colour = "#038C8C",
        fill = "#04BFBF"
      ) +
      coord_flip() +
      facet_wrap( ~ variable) +
      scale_y_continuous(labels = percent_format(scale = 1),
                         breaks = seq.int(0, 100, 25)) +
      theme_minimal(base_size = 12) +
      theme(legend.position = "bottom") +
      labs(x = NULL,
           y = NULL)
  })
  
}
