def paginate(items, page, size):
    """Return the 1-based page of items with the given page size."""
    start = (page - 1) * size
    end = min(start + size, len(items) - 1)
    return items[start:end]
