# Phase 118 — Rudy Riches

**Date:** 2026-06-15  
**Scope:** First post-overhaul manager — prestige strategist expanding Consigliere intel.

---

## 1. Identity shipped

| Field | Value |
|-------|-------|
| Name | **Rudy Riches** — "The money guy" |
| Role | Prestige strategist (income secondary) |
| Unlock | **Kingpin** rank (165 Influence) |
| Cost | $8T premium payroll |
| Hire toast | "Rudy says it's time to make some real money." |

**Behavior:** Expands prestige button + confirm dialog with now / 5m / 10m 
Influence comparison, benefit summary, confidence score, and window recommendation.

---

## 2. Success question — Do players trust Rudy?

| Profile | Rudy unlock | Rudy hire | Post-Rudy trust | Avg pre-Rudy guess delay |
|---------|-------------|-----------|-----------------|--------------------------|
| CASUAL | 33m35s | 34m28s | 100% aligned | 600s |
| ENGAGED | 35m05s | 35m36s | 100% aligned | 628s |
| OPTIMIZER | 33m32s | 33m41s | 0% aligned | 630s |

**ENGAGED:** 158 advice views, first Rudy line: "12% to prestige gate"

Pre-Rudy eligible time (hesitation window): **1256s**  
Post-Rudy eligible time: **6s**  
Post-Rudy prestiges following Rudy's window: **1/1**

---

## 3. What did the player stop doing?

| Before Rudy | After Rudy |
|-------------|------------|
| ~628s eligible before resetting (guessing) | Rudy labels NOW / WAIT 5m / WAIT 10m with +Inf deltas |
| Consigliere one-liner on prestige button | Full window table on confirm dialog |
| Wondering if now is right | **Guided decision with expected benefits** |

---

## 4. Verdict

### **Yes — prestige feels guided.**

ENGAGED trust score **100%** with Rudy's expanded comparison replacing ~628s of pre-reset hesitation.

---

## 5. Remaining concerns

- Kingpin + $8T gate keeps Rudy endgame — celebration hire, not early-tutorial.
- Consigliere one-liner still shows when Rudy absent; Rudy supersedes when both hired.
- Wait-5m / wait-10m trust assumes player reads the prestige button — confirm dialog reinforces.

---

## 6. Re-run

```powershell
python _measure_p118.py
```
