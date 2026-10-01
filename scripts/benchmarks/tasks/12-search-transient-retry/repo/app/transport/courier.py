def dispatch(blob, channel):
    """Hand a blob to the channel and return the receipt."""
    return channel.send(blob)
