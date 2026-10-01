def find_user(conn, name):
    """Return (id, name) for the user with the given name, or None."""
    return conn.execute(f"SELECT id, name FROM users WHERE name = '{name}'").fetchone()
