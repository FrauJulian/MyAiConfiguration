from app.api import fetch


def main(url):
    return fetch(url, retries=2)
