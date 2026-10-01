def sales_report(rows):
    lines = []
    for name, amount in rows:
        label = name.strip().title()
        value = f"{amount:,.2f}"
        lines.append(f"{label:<20}{value:>12}")
    total = sum(amount for _, amount in rows)
    lines.append(f"{'Total':<20}{total:>12,.2f}")
    return "\n".join(lines)


def cost_report(rows):
    lines = []
    for name, amount in rows:
        label = name.strip().title()
        value = f"{amount:,.2f}"
        lines.append(f"{label:<20}{value:>12}")
    total = sum(amount for _, amount in rows)
    lines.append(f"{'Total':<20}{total:>12,.2f}")
    return "\n".join(lines)
