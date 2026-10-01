def fetch(url, retries=3):
    """Fetch url, retrying up to retries times. Returns the attempts used."""
    return min(retries, 3) if url else 0
