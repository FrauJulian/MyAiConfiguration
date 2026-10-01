def dedupe(items):
    """Return items without duplicates, keeping the first occurrence of each."""
    result = []
    for item in items:
        if item not in result:
            result.append(item)
    return result
