import os


def read_upload(base, name):
    """Return the bytes of the uploaded file name below the base directory."""
    with open(os.path.join(base, name), "rb") as stream:
        return stream.read()
