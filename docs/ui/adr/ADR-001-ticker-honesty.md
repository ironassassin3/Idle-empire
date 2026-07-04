# ADR-001 — Ticker honesty

**Status:** Accepted (owner-approved by starting V2-A, 2026-07-03)
**Context:** The performing ledger (UI_MARKET_SUPREMACY_SPEC §4.1) animates the
masthead balance with a count-up ticker. Animated currency displays in F2P
games are a documented dark-pattern vector (inflating perceived wealth to
drive purchases). Our trust pillar (P3) forbids that.

**Options considered:**
1. Symmetric easing both directions — smoothest, but the display exceeds the
   true balance for up to 400ms after every spend.
2. Ease upward, snap downward — display can only ever *lag* the truth, never
   overstate it; spends feel instant and decisive.
3. No animation — honest but kills pillar P2 (the ledger performs).

**Decision:** Option 2. The displayed balance may NEVER exceed the true
balance. Gains ease in (≤400ms catch-up, snap when within 1%); spends snap
down the same frame, accompanied by the bone-white dip pulse.

**Consequences:** Ticker state lives in the masthead only (no save fields).
A shell_smoke assertion enforces `shown_balance() <= GameState.balance` every
frame (float epsilon). Any future animated resource display (Influence,
Respect) inherits this rule.
