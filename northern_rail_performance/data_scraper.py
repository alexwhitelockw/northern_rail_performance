from bs4 import BeautifulSoup
import pandas as pd
import re
import requests
import sqlite3


def tidy_service_quality_table(table_html):
    sq_data = pd.read_html(
        str(table_html)
    )[0]

    date_range = (
        sq_data
        .filter(regex=r"^\d")
        .iloc[:2]
        .melt(
            var_name="period",
            value_name="date"
            )
        .groupby(["period"])["date"]
        .apply(lambda x: "-".join(x))
        .reset_index()
    )

    service_quality_table = (
        sq_data
        .loc[sq_data["Component"].notna()]
        .rename(
            lambda x: re.sub(r"Benchmark \d{4}/\d{2}", "Benchmark", x),
            axis="columns"
        )
        .melt(
            id_vars=["Component", "Area", "Benchmark"],
            var_name="period",
            value_name="performance"
        )
        .merge(
            date_range,
            left_on="period",
            right_on="period"
        )
    )

    return service_quality_table

def scrape_service_quality():
    url = "https://www.northernrailway.co.uk/about-us/customer/service-quality"

    try:
        response = requests.get(url)
        response.raise_for_status()
    except requests.RequestException as e:
        print(f"Request failed: {e}")
        return None
    
    page_html = BeautifulSoup(response.text, "lxml")
    table_area = page_html.find_all("div", "wysiwyg clearfix")

    service_quality_tables = pd.DataFrame()
    end_of_year_tables = pd.DataFrame()

    for area in table_area:
        service_tables = area.find_all("table")
        year_covered = area.find("h2")

        if service_tables:
            if re.search(r"\d$", year_covered.text):
                for table in service_tables:
                    service_quality_table = tidy_service_quality_table(table)
                    service_quality_tables = pd.concat([
                        service_quality_tables, service_quality_table
                    ])
            else:
                end_of_year_table = pd.read_html(str(service_tables))[0]
                end_of_year_table = (
                    end_of_year_table
                    .rename(
                        columns={
                            "Unnamed: 0": "Component",
                            "Unnamed: 1": "Area"
                            }
                    )
                    .melt(
                        id_vars=["Component", "Area"],
                        var_name="year",
                        value_name="performance"
                    )
                )
                end_of_year_tables = pd.concat([
                    end_of_year_tables, end_of_year_table
                ])
    
    return service_quality_tables, end_of_year_tables

if __name__ == "__main__":
    conn = sqlite3.connect("northern_rail_performance/data/database/northern_rail_performance.db")
    service_quality_table, end_of_year_table = scrape_service_quality()

    service_quality_table.to_sql(name="service_quality", con=conn, if_exists="replace")
    end_of_year_table.to_sql(name="eoy_service_quality", con=conn, if_exists="replace")
