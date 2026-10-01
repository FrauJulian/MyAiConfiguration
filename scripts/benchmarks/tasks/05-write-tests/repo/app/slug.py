import re
import unicodedata


def slugify(text, max_length=50):
    """Lowercase ASCII slug with single hyphens, trimmed to max_length without a trailing hyphen."""
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    text = re.sub(r"[^a-zA-Z0-9]+", "-", text).strip("-").lower()
    return text[:max_length].rstrip("-")
