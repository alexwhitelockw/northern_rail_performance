library(bsicons)
library(bslib)
library(ggplot2)
library(leaflet)
library(RSQLite)
library(shiny)

page_navbar(
  title = "Train Company Performance",
  theme = bs_theme(bootswatch = "sandstone",
                   base_font = font_google("Roboto")),
  bg = "#038C8C",
  nav_panel(
    title = "Service Performance",
    layout_columns(
      value_box(
        title = "Customer Service",
        showcase = bs_icon("telephone"),
        theme = "primary",
        value = textOutput("customer_service_performance")
      ),
      value_box(
        title = "Station",
        showcase = bs_icon("ticket"),
        theme = "light",
        value = textOutput("station_service_performance")
      ),
      value_box(
        title = "Train",
        showcase = bs_icon("train-front"),
        theme = "danger",
        value = textOutput("train_service_performance")
      )
    ),
    layout_columns(
      card(card_header("End of Year Performance"),
           card_body(plotOutput("eoy_performance"))),
      card(
        card_header("Service Performance by Period"),
        card_body(plotOutput("service_performance"))
      )
    )
  ),
  nav_panel(
    title = "Delays",
    layout_columns(
      value_box(
        title = "Early",
        showcase = bs_icon("chevron-up"),
        theme = "success",
        value = textOutput("overall_delay_early")
      ),
      value_box(
        title = "On Time",
        showcase = bs_icon("check"),
        theme = "primary",
        value = textOutput("overall_delay_ontime")
      ),
      value_box(
        title = "Within 15 Minutes",
        showcase = bs_icon("chevron-down"),
        theme = "orange",
        value = textOutput("overall_delay_15mins")
      ),
      value_box(
        title = "Cancelled",
        showcase = bs_icon("x"),
        theme = "danger",
        value = textOutput("overall_delay_cancelled")
      )
    ),
    layout_columns(card(
      card_header("Delay Locations"),
      card_body(leafletOutput("delay_locations"))
    )),
    layout_columns(card(
      card_header("Delays by Service Group"),
      card_body(plotOutput("service_group_delay_performance"))
    ))
  )
)
