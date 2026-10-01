from dataclasses import dataclass, field
from datetime import date


@dataclass
class Account:
    tier: str  # "evaluation" or "paid"
    evaluation_until: date | None = None
    entries: list = field(default_factory=list)
