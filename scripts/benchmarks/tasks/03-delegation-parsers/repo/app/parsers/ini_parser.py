def parse_ini(text):
    """Parse INI text into {section: {key: value}}.

    Ignore lines starting with ; or #, strip whitespace, keep keys before the first section under "".
    """
    raise NotImplementedError
