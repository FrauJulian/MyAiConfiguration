from app.config import DEFAULT_TIMEOUT


def request(url, timeout=None):
    """Return the effective timeout in seconds; defaults to DEFAULT_TIMEOUT (30 seconds)."""
    return timeout if timeout is not None else DEFAULT_TIMEOUT
