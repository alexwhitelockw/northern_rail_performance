import pandas as pd
from pathlib import Path
import PyPDF2
import PyPDF2.errors
import re
import sqlite3


def extract_pdf_text(filepath):
    try:
        reader = PyPDF2.PdfReader(filepath)
        pdf_text = [page.extract_text() for page in reader.pages]
        return pdf_text
    except PyPDF2.errors.PdfReadError as e:
        print(f"{filepath} could not be read: {e}")

def on_time_graph_text(pdf_text):
    on_time_data = dict()

    pdf_text = pdf_text[0].splitlines()

    # Extract Report Start and End Dates
    report_date = pdf_text[0]
    start_date, end_date = [date.strip() for date in report_date.split("to")]
    start_date = start_date.replace("From", "").strip()
    
    # Extract Report Percentages
    pattern_two_digits = r"(\d{2}\.\d)"
    pattern_one_digit = r"(\d{1}\.\d)"

    matches_two_digits = re.findall(pattern_two_digits, pdf_text[1])
    matches_one_digit = re.findall(pattern_one_digit, pdf_text[2])

    percentages = matches_two_digits + matches_one_digit

    # Ensure the correct number of percentages is extracted
    if len(percentages) < 10:
        raise ValueError("Not enough percentage values found")

    percentage_labels = [
        'Early', 'On Time', 'Within 3 mins', 'Within 5 mins', 'Within 10 mins', 
        'Within 15 mins', '15 mins +', '20 mins +', '30 mins +', 'Cancelled']
    
    percentage_with_label = zip(percentage_labels, percentages)

    # Output to JSON
    on_time_data["start_date"] = start_date
    on_time_data["end_date"] = end_date

    for percentage_label in percentage_with_label:
        label, percentage = percentage_label
        on_time_data[label] = percentage

    on_time_data = pd.DataFrame(on_time_data, index=[0])

    return on_time_data

def reasons_for_delay(pdf_text):
    # Split Text into Lines
    pdf_text = pdf_text[0].splitlines()

    # Extract the delay reasons from the PDF
    delay_reasons = [line for line in pdf_text if re.match(r"[0-9]{1,2}\s", line)]

    delay_reason_data = []
    for delay_reason in delay_reasons:
        delay_reason = re.split(r"(^[0-9]{1,2}\s[A-Za-z]+)|([-])", delay_reason)
        delay_reason = [reason.strip() for reason in delay_reason if reason is not None and reason not in ("", "-")]
        delay_reason_data.append(delay_reason)

    delay_reason_data = pd.DataFrame(
        data=delay_reason_data,
        columns=["delay_date", "delay_reason", "delay_location"]
    )

    return delay_reason_data


def service_group_performance(pdf_text):
    # Text from the First Page
    pdf_text = pdf_text[0]

    # Report Date Range
    report_date_range = re.findall(r"([0-9]{1,2}\s[A-Za-z]+\s[0-9]{4})", pdf_text)
    report_start_date, report_end_date = report_date_range

    # Split Text into Lines
    pdf_text = pdf_text.splitlines()

    # Identification of Service Group Rows
    service_group_pattern = r"120\+|Tyne| |Lancashire|Local|Inter|North|South|West|Merseyrail"
    service_group_performance = [line for line in pdf_text if re.match(service_group_pattern, line)]

    # Extract Column Names
    column_name_one = " ".join(service_group_performance[4].split())
    column_name_one = re.search(r"(Short.*)", column_name_one).group(0).split()

    column_name_two = " ".join(service_group_performance[5].split())
    column_name_two = re.split(r"\s(?=[A-Z])|\s(?=[a-z])", column_name_two)

    column_names = []

    # Join the second line of text to first line where the second line is the text that follows
    for index, column in enumerate(column_name_one):
        if index < len(column_name_two):
            column_names.append(" ".join([column, column_name_two[index]]))
        else:
            column_names.append(column)
    
    column_names.insert(0, "Service Group")

    # Extract Service Group Data
    # Data is on two rows with a mix of percentage and counts on the first line
    # and percentages on the second line. This stitches the first and
    # second lines to provide just the percentages.
    service_group_data = service_group_performance[7:27]

    service_group_rows = []

    index = 0
    while index < len(service_group_data):
        data_line_one = service_group_data[index]
        data_line_one = " ".join(data_line_one.split())
        data_line_one = re.split(r"\s(?=\d)", data_line_one)

        data_line_two = service_group_data[index + 1]

        service_variation_match = re.match(r"Local|Inter Urban", data_line_two)

        service_group = data_line_one[0]
        if service_variation_match:
            service_group = " ".join([service_group, service_variation_match.group(0)])

        data_line_two = re.sub(r"Local|Inter Urban|From[\s\w]+", "", data_line_two)
        data_line_two = data_line_two.split()

        data_line_two.insert(0, service_group)
        data_line_two.insert(3, data_line_one[3])
        data_line_two.insert(4, data_line_one[4])
        data_line_two.insert(5, data_line_one[5])

        service_group_rows.append(data_line_two)

        index += 2
    
    service_group_data = pd.DataFrame(
        data=service_group_rows,
        columns=column_names
    )

    service_group_data.loc[:, "report_start_date"] = report_start_date
    service_group_data.loc[:, "report_end_date"] = report_end_date

    return service_group_data


if __name__ == "__main__":
    performance_reports = Path("northern_rail_performance/data/reports").glob("*.pdf")
    conn = sqlite3.connect("northern_rail_performance/data/database/northern_rail_performance.db")

    for report in performance_reports:
        if re.match(r"^On_Time_Graph", report.name):
            pdf_text = extract_pdf_text(report)
            on_time_data = on_time_graph_text(pdf_text)
            on_time_data.to_sql(
                name="on_time_data",
                con=conn,
                if_exists="append"
            )
        elif re.match(r"^Customer_Promise", report.name):
            pdf_text = extract_pdf_text(report)

            service_group_performance_data = service_group_performance(pdf_text)
            service_group_performance_data.to_sql(
                name="service_group_performance",
                con=conn,
                if_exists="append"
            )

            delay_reason_data = reasons_for_delay(pdf_text)
            delay_reason_data.to_sql(
                name="delay_reasons",
                con=conn,
                if_exists="append"
            )
        else:
            print(f"Skipping {report}.")
