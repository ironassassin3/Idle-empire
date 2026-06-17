"""Phase 104 — debug-only money source attribution (no gameplay effect)."""
from __future__ import annotations

import config

SOURCES = (
    'money_from_clicks',
    'money_from_crit_clicks',
    'money_from_buildings',
    'money_from_operations',
    'money_from_territories',
    'money_from_hustle',
    'money_from_other',
)


def _enabled() -> bool:
    return bool(getattr(config, 'DEBUG_MONEY_SOURCES', False))


def reset(state) -> None:
    if not _enabled():
        return
    state._money_sources = {k: 0.0 for k in SOURCES}


def credit(state, amount: float, source: str) -> None:
    if not _enabled() or amount <= 0.0:
        return
    if source not in SOURCES:
        source = 'money_from_other'
    bucket = getattr(state, '_money_sources', None)
    if bucket is None:
        bucket = {k: 0.0 for k in SOURCES}
        state._money_sources = bucket
    bucket[source] = bucket.get(source, 0.0) + amount


def credit_click(state, amount: float, *, pre_crit: float, had_crit: bool,
                 had_hustle: bool) -> None:
    """Split a click payout into base / hustle / crit buckets."""
    if not _enabled():
        return
    hustle_amt = 0.0
    without_hustle = pre_crit
    if had_hustle:
        mult = getattr(config, 'CLICK_HUSTLE_MULT', 1.0)
        if mult > 1.0:
            without_hustle = pre_crit / mult
            hustle_amt = pre_crit - without_hustle
    crit_amt = (amount - pre_crit) if had_crit else 0.0
    credit(state, without_hustle, 'money_from_clicks')
    if hustle_amt > 0.0:
        credit(state, hustle_amt, 'money_from_hustle')
    if crit_amt > 0.0:
        credit(state, crit_amt, 'money_from_crit_clicks')


def totals(state) -> dict[str, float]:
    bucket = getattr(state, '_money_sources', None) or {}
    return {k: float(bucket.get(k, 0.0)) for k in SOURCES}


def click_share_pct(state) -> float:
    t = totals(state)
    click_total = (t['money_from_clicks'] + t['money_from_crit_clicks']
                   + t['money_from_hustle'])
    grand = sum(t.values()) + 1e-9
    return click_total / grand * 100.0


def format_report(state) -> str:
    t = totals(state)
    grand = sum(t.values()) + 1e-9
    lines = ['--- money source debug ---']
    for key in SOURCES:
        val = t[key]
        lines.append(f'  {key}: {val:,.0f} ({val / grand * 100:.1f}%)')
    lines.append(f'  click+buff total: {click_share_pct(state):.1f}%')
    return '\n'.join(lines)


def maybe_print(state) -> None:
    if _enabled():
        print(format_report(state))
