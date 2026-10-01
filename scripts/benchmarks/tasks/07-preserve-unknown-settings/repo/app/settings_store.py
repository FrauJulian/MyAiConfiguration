import json

KNOWN = ("theme", "language")


def save_settings(path, updates):
    """Apply updates to the JSON settings file at path."""
    try:
        with open(path, encoding="utf-8") as stream:
            current = json.load(stream)
    except FileNotFoundError:
        current = {}
    merged = {key: updates.get(key, current.get(key)) for key in KNOWN if key in updates or key in current}
    with open(path, "w", encoding="utf-8") as stream:
        json.dump(merged, stream, indent=2)
