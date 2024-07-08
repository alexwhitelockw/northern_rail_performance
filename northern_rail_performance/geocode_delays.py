from geopy.geocoders import Nominatim
import pandas as pd
import sqlite3


if __name__ == "__main__":
    conn = sqlite3.connect("northern_rail_performance/data/database/northern_rail_performance.db")
    delay_reasons = pd.read_sql(con=conn, sql="SELECT DISTINCT * FROM DELAY_REASONS;")

    geolocator = Nominatim(user_agent="train_performance_delays")

    delay_reasons.loc[:, "delay_location"] = delay_reasons["delay_location"] + ", UK"

    delay_reasons.loc[:, "geo_code"] = delay_reasons["delay_location"].apply(geolocator.geocode)

    delay_reasons.loc[:, "latitude"] = delay_reasons["geo_code"].apply(lambda x: x.latitude)
    delay_reasons.loc[:, "longitude"] = delay_reasons["geo_code"].apply(lambda x: x.longitude)

    delay_reasons = delay_reasons.drop(columns="geo_code")

    delay_reasons.to_sql("delay_reasons_geocode", con=conn, if_exists="replace")
