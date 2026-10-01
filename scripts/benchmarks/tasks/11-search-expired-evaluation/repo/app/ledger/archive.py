from datetime import date


def render_period_summary(account, period, today=None):
    """Build the period summary document for an account."""
    today = today or date.today()
    lines = [f"{entry.label}: {entry.amount:.2f}" for entry in account.entries if entry.period == period]
    return "\n".join(lines).encode()
