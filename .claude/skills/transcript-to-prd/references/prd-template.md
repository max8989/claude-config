# PRD template & section contract

This is the **fixed skeleton** every generated PRD must follow, in order. Render
all headings and body text in the **target language** the user chose. The
section list never changes — even a section with no source material still
appears, stating that nothing in the transcript covered it (which is itself a
useful signal).

Each requirement, objective, and constraint carries a stable **ID** so the
verification appendix can reference it. Use prefixes: `FR-##` (functional),
`NFR-##` (non-functional), `INT-##` (integration), `CON-##` (constraint),
`OBJ-##` (objective), `AS-##` (assumption), `Q-##` (open question).

## Provenance tags — the core discipline

Never present an inference as a fact. Tag anything that is not directly stated:

- Untagged text = **stated in the transcript** (you can point to where).
- `[assumption]` = a reasonable inference you made to keep the PRD coherent.
  Every assumption must ALSO appear as an `AS-##` row in the Assumptions section.
- `[open question]` = a genuine unknown that needs a human answer. Every one
  must ALSO appear as a `Q-##` row in the Open Questions section.

If you're unsure whether something is stated or inferred, it's inferred. When in
doubt, downgrade to `[assumption]` or `[open question]` rather than assert.

## Heading map (use the target language's column)

| Canonical section        | Français                        | English                     |
|--------------------------|----------------------------------|-----------------------------|
| Title                    | PRD — <projet>                   | PRD — <project>             |
| Metadata block           | Informations                     | Document info               |
| Executive summary        | Résumé exécutif                  | Executive summary           |
| Business problem         | Problème business                | Business problem            |
| Objectives & success     | Objectifs et succès              | Objectives & success metrics|
| Stakeholders & users     | Parties prenantes et utilisateurs| Stakeholders & users        |
| Scope (in / out)         | Périmètre (inclus / exclu)       | Scope (in / out)            |
| Functional requirements  | Exigences fonctionnelles         | Functional requirements     |
| Non-functional req.      | Exigences non fonctionnelles     | Non-functional requirements |
| Integrations             | Intégrations                     | Integrations                |
| Constraints              | Contraintes                      | Constraints                 |
| Assumptions              | Hypothèses                       | Assumptions                 |
| Open questions           | Questions ouvertes               | Open questions              |
| Verification appendix    | Vérification de traçabilité      | Traceability verification   |

For any other target language, translate these headings faithfully and keep the
same order and the same English ID prefixes (FR-, NFR-, …) so the document stays
machine-referenceable.

## Section-by-section contract

### Document info
A small table: project name (or `[assumption]`/`[open question]` if unnamed),
source (transcript file + duration), transcript language, PRD language, date,
and author = "Generated from transcript — pending human review".

### Executive summary
3–6 sentences: what is being built, for whom, and why it matters. No new facts —
only a synthesis of what's below.

### Business problem
The pain in the current state, in the stakeholders' own framing. Quote or
closely paraphrase the transcript. Explain impact (time lost, cost, risk).

### Objectives & success metrics
`OBJ-##` rows. What the solution must achieve. If the transcript implies a goal
but gives no measurable target, state the goal and add a `[open question]` for
the metric rather than inventing a number.

### Stakeholders & users
Who was in the conversation, who the end users are, their roles and contexts.
Tag anyone whose role is inferred.

### Scope (in / out)
Two short lists. "Out of scope" captures things explicitly deferred/rejected in
the transcript ("on verra plus tard", "pas pour l'instant"). Empty list → say so.

### Functional requirements
The heart of the PRD. `FR-##` rows, grouped by feature area. Each row: an
imperative capability statement ("The system shall …" / "Le système doit …"),
plus a short source cue (paraphrased). Split compound needs into atomic rows so
each maps cleanly in the verification appendix. This is where most transcript
requirements land — be exhaustive; missing one here is the failure mode the
verification step exists to catch.

### Non-functional requirements
`NFR-##`: performance, availability, security/privacy, accessibility, devices
(e.g. tablet/mobile), offline, localization. In regulated domains (health,
finance) surface compliance as `[open question]` if unstated — don't assert it.

### Integrations
`INT-##`: other systems, data sources, hardware, exports/imports mentioned.

### Constraints
`CON-##`: budget, timeline, tech, organizational, approval processes.

### Assumptions
`AS-##` table: assumption | why it was made | impact if wrong. Mirror every
`[assumption]` tag used above.

### Open questions
`Q-##` table: question | why it matters | who can answer. Mirror every
`[open question]` tag. This is the list the user should walk away able to act on.

### Verification appendix (traceability)
See SKILL.md — this is a required, non-negotiable final step. A table with one
row per distinct need detected in the transcript:

| # | Need (paraphrased from transcript) | Covered by | Status |
|---|------------------------------------|-----------|--------|

`Covered by` = the ID(s) above (e.g. FR-03, OBJ-01). `Status` = ✅ Covered,
⚠️ Partial, or ❌ Missing. End with a one-line completeness statement, e.g.
"12 needs detected, 12 covered (0 missing)." If anything is ❌ or ⚠️, fix the
PRD before finishing rather than shipping a known gap.
