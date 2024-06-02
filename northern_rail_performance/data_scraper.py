from bs4 import BeautifulSoup
import re
import requests


def scrape_performance_pdf_links():
    url = "https://www.northernrailway.co.uk/about-us/performance"

    try:
        response = requests.get(url)
        response.raise_for_status()
    except requests.RequestException as e:
        print(f"Request failed: {e}")
        return None
    
    page_html = BeautifulSoup(response.text, "lxml")
    page_links = page_html.find_all("a")
    pdf_links = [link.get("href") for link in page_links if link.get("href") and re.search(r".pdf$", link.get("href"))]
    
    return pdf_links

def download_performance_pdfs(pdf_link):
    
    try:
        response = requests.get(pdf_link)
        response.raise_for_status()
    except requests.RequestException as e:
        print(f"Request failed: {e}")
        return None
    
    file_name = re.search(r"[\w%\-_]+.pdf$", pdf_link).group(0).replace("%20", "_")

    with open(f"northern_rail_performance/data/reports/{file_name}", "wb") as f:
        f.write(response.content)

def save_pdf_link(pdf_link):
    with open("northern_rail_performance/data/links/viewed_links.txt", "a") as f:
        f.write(f"{pdf_link}\n")

def load_viewed_links():
    with open("northern_rail_performance/data/links/viewed_links.txt", "r") as f:
        return f.read().splitlines()

if __name__ == "__main__":
    pdf_links = scrape_performance_pdf_links()
    viewed_links = load_viewed_links()

    for link in pdf_links:
        if link not in viewed_links:
            download_performance_pdfs(link)
            save_pdf_link(link)
            print(f"{link} report downloaded.")
        else:
            print(f"{link} previously downloaded, skipped.")
