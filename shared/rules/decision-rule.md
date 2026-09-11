## Decision Rule

* Gather evidence from the repository, available tooling, and current technical sources before making technical decisions.
* Make technical implementation and code-style decisions independently when existing code, reliable documentation, or established standards provide sufficient evidence and the decision is reversible.
* Ask the user when technical uncertainty remains material, multiple meaningful options remain, or the decision has a high-impact or difficult-to-reverse effect.
* Ask the user before deciding business behavior, domain rules, validation rules, status transitions, permissions, database rules, error behavior, UI, UX, or other user-visible behavior when the requested behavior is missing, ambiguous, contradictory, or open to interpretation.
* Implement explicitly specified behavior without asking again.
* Ask the user when changing or choosing an API, database model, configuration format, external contract, or compatibility behavior remains ambiguous or has multiple meaningful interpretations.
* Do not invent business requirements or silently resolve contradictions.
* Treat direct user input as the final decision for behavior and requirements.
