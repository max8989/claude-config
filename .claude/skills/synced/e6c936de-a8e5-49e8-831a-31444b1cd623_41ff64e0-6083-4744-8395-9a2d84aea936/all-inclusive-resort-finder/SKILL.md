---
name: "all-inclusive-resort-finder"
description: "Find, vet and score all-inclusive resorts for given dates, origin and traveller(s) using live Google reviews (bugs, rooms, food safety, solo-female security) and live package prices, then write a ranked doc."
---

# All-inclusive resort finder

Use when the user wants the best all-inclusive for specific dates, departure city and party (e.g. "solo, Ottawa, Nov 7-14, Jamaica"). Read reviews live; never rely on memory.

## 0. Clarify (AskUserQuestion, once)
- Destination(s), exact dates, departure airport(s), number of travellers, budget ceiling.
- Whether the traveller is a woman travelling alone (security weight applies by default for solo travellers; ask if unclear).
- Output: a Claude Docs doc unless they ask otherwise.

## 1. Feasibility check first
- Web-search for operator suspensions/advisories for the destination (e.g. Cuba suspended by all Canadian operators in June 2026). If impossible, say so and offer alternatives before doing any scoring.
- Web-search for hurricane/closure status of candidate resorts (e.g. Catalonia Montego Bay closed until 2028). Drop closed resorts with a one-line note.

## 2. Prices (Claude in Chrome preferred; user is signed in)
- Package sellers for the origin: Air Canada Vacations, WestJet Vacations, Sunwing, Transat. Search exact dates, 1 room, correct adult count. Record the all-in total and the search URL as the booking link.
- DIY: Expedia hotel-only (7 nights) + Google Flights best-value round trip. Note DIY excludes transfers.
- Gotchas: close newsletter popups; reject non-essential cookies; Expedia may render French (match "au total"); WestJet opens results in a new tab (strip target=_blank); Sunwing's widget may crash (report it, don't loop).

## 3. Reviews (Chrome, Google Maps / Google Travel)
- Review link format: https://www.google.com/maps?cid=<decimal cid>.
- Maps: sort by Newest, read 50-100 newest. Maps throttles at ~10 reviews when searching; use Google Travel's hotel review search (input aria-label "Review search input"; set value with the native setter, dispatch Enter) for keyword searches.
- Keep the Chrome window visible (hidden windows stall Maps). Focus inputs with JS; never blind-click (can open "Write a review" / Share). Keep JS calls under ~45s and outputs short; strip capitalised names from excerpts or output gets blocked.
- Segment reviews by date with /((?:Edited )?(?:an?|\d+) (?:hour|day|week|month|year)s? ago) on /. Keep only the past 2 years; count past 12 months separately.

Searches per resort:
- Bugs: "cockroach", "roach" (regex \broach to avoid "approachable"), "bed bugs", "bites", "ants" (\bants\b).
- Room: "dirty", "mould/mold", "smell", "AC".
- Food safety: "food poisoning", "sick", "diarrhea", "feeling sick". Count only reviews blaming food, drink or water; normalise by total review count.
- Security (solo female): "harassed", "safe", "security", "stolen".
  - NEG regex: harass|creep|uncomfortab|unsafe|not safe|didn.t feel safe|felt unsafe|theft|thief|stole|stolen|robbed|robbery|break.?in|broke into|followed me|grop|aggressive|hustl|propositio|hit on me|hitting on|sexual|assault|scam|security (was|is) (lax|poor|non|bad)|no security|intoxicated|drunk (guest|men|staff)
  - POS regex: felt (very |completely |totally )?safe|very safe|safe (and|place|resort)|secure|safe as a (solo|single|woman|female)|solo female|travell?ing (alone|solo)|as a single (woman|female)|woman travell?ing alone|security (was|is) (great|excellent|good|everywhere|visible)
  - Read every match. Severity order: staff sexual harassment/following a woman/locating her room > staff entering rooms or giving out room numbers > harassment by other guests/day-pass visitors > beach vendors/drug dealers > thefts from rooms or safes > absent patrols. Thefts appear almost everywhere, so a few cost less than one harassment report. Explicit "felt safe as a woman travelling alone" reports raise the score.
  - Anchor: ~7 = no harassment, a few thefts, positive solo-female reports; ~5 = one staff sexual-comment report; ~2 = staff harassing/following solo women.

## 4. Scoring (0-10 per factor)
Weights: bugs 20%, security (solo female) 20%, room condition 15%, food safety 13%, price 12%, service 10%, overall rating 10%.
- Price score = 10 - (price - cheapest_finalist_anchor)/292, clamped 0-10 (anchor stays fixed across refreshes so scores are comparable; first run used $2,999).
- Rating: Google stars and 5-star share, discounted for floods of short reviews that just name a staff member.
- Compute totals in Python; report 2 decimals when places are within 0.05 and call it a tie.

## 5. Output (Claude Docs)
- Summary (best pick, price, why, date of check).
- How scores work (weights + method + search dates).
- Seller table (what each seller offers for the dates).
- All-candidates table: rank, resort, how to book, price, change, food-illness counts (past yr / prior yr), bugs, room, food safety, security, price score, service, rating, score.
- Top 5 in detail: heading "N. Resort: X/10, $price", review link + booking link, Pros, Cons, Food safety, Security bullets.
- Dropped resorts with one-line reasons; notes before booking (DIY excludes transfers, packages rebook on cancellations, prices change).
- Docs editing: insert new bullets after a listItem id (not its paragraph id, which nests); when moving and replacing the same block, put moves first.

## 6. Refreshes
On "re-run with today's prices" or a new criterion: keep the anchor, update only the changed inputs, rescore, add a dated "Update" note, and keep older docs unchanged unless asked.