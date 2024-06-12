import pandas as pd
from shiny import App, reactive, render, ui
import seaborn as sns


app_ui = ui.page_bootstrap(
    ui.h1("Train Company Service Quality Performance"),
    ui.input_select(
        "service_component",
        "Service Quality Area",
        choices=["Customer Service", "Station", "Train"], 
        selected="Train"),
    ui.output_plot()
)

def server(input, output, session):
    return None

    sns.

app = App(app_ui, server)