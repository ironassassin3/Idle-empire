"""Lightweight, local-only analytics for soft-launch retention tuning.

Records key funnel/retention events to a newline-delimited JSON file
(`analytics.jsonl`) with timestamps. No network, no PII — this is the
instrumentation you need to SEE where players churn during a soft launch
(the #1 reason teams fly blind in week one).

Design goals:
- Zero gameplay impact: best-effort, never raises, cheap.
- Funnel-first: the events that matter for D1/D7 retention are first-class
  helpers (session start/end, first prestige, rank ups, prestige loop, churn
  signals like "quit while a goal was one step away").
- Easy to wire to a real backend later: every event is `{ts, session, event, props}`.

Usage:
    import src.analytics as analytics
    analytics.start_session(state)
    analytics.track("prestige", {"count": n, "influence_gain": g})
    analytics.end_session(state)
"""
from __future__ import annotations
import json
import os
import time
import uuid

ANALYTICS_VERSION = 2          # bump when schema changes
_LOG_PATH    = "analytics.jsonl"
_LOG_PATH_OLD = "analytics.jsonl.old"
_MAX_FILE_BYTES = 5 * 1024 * 1024   # 5 MB cap before rotation

_session_id    = None
_session_start = 0.0
_enabled       = True
_event_count   = 0


def _session_elapsed() -> float:
    """Seconds since session start — for time-to-first-X beta telemetry."""
    return max(0.0, time.time() - _session_start) if _session_start else 0.0


def set_enabled(on: bool) -> None:
    """Allow players to opt out (privacy) — analytics is purely local but still
    respects a kill switch. Persisted through the save system."""
    global _enabled
    _enabled = bool(on)


def is_enabled() -> bool:
    return _enabled


def _rotate_if_needed() -> None:
    """Rotate log file if it exceeds the size cap (rename → .old, start fresh)."""
    try:
        if os.path.exists(_LOG_PATH) and os.path.getsize(_LOG_PATH) >= _MAX_FILE_BYTES:
            if os.path.exists(_LOG_PATH_OLD):
                os.remove(_LOG_PATH_OLD)
            os.rename(_LOG_PATH, _LOG_PATH_OLD)
    except OSError:
        pass


def _repair_if_corrupt() -> None:
    """If the log file can't be appended to due to corruption, rename and start fresh."""
    if not os.path.exists(_LOG_PATH):
        return
    try:
        with open(_LOG_PATH, "a", encoding="utf-8"):
            pass
    except OSError:
        try:
            os.rename(_LOG_PATH, _LOG_PATH + ".corrupt")
        except OSError:
            pass


def _write(event: str, props: dict | None = None) -> None:
    if not _enabled:
        return
    global _event_count
    try:
        _rotate_if_needed()
        rec = {
            "v":       ANALYTICS_VERSION,
            "ts":      round(time.time(), 3),
            "session": _session_id,
            "event":   event,
            "props":   props or {},
        }
        with open(_LOG_PATH, "a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
        _event_count += 1
    except Exception:
        # Never let analytics break the game.
        pass


def track(event: str, props: dict | None = None) -> None:
    """Record an arbitrary event."""
    _write(event, props)


# ─── Funnel helpers (the retention-critical events) ──────────────────────────

def start_session(state) -> None:
    global _session_id, _session_start
    _repair_if_corrupt()
    _session_id = uuid.uuid4().hex[:12]
    _session_start = time.time()
    _write("session_start", {
        "prestige_count": int(getattr(state, "_prestige_count", 0) or 0),
        "influence": int(getattr(state, "prestige_tokens", 0) or 0),
        "lifetime_earnings": float(getattr(state, "lifetime_earnings", 0.0) or 0.0),
        "buildings": sum(b.owned for b in getattr(state, "buildings", [])),
        "returning": int(getattr(state, "_prestige_count", 0) or 0) > 0
                     or float(getattr(state, "_play_time", 0.0) or 0.0) > 0,
    })


def end_session(state) -> None:
    dur = max(0.0, time.time() - _session_start) if _session_start else 0.0
    _write("session_end", {
        "duration_s": round(dur, 1),
        "prestige_count": int(getattr(state, "_prestige_count", 0) or 0),
        "influence": int(getattr(state, "prestige_tokens", 0) or 0),
        "lifetime_earnings": float(getattr(state, "lifetime_earnings", 0.0) or 0.0),
        # Churn signal: was the player one step from a goal/prestige when they left?
        "near_prestige": _near_prestige(state),
    })


def first_building() -> None:
    _write("first_building", {"session_time_s": round(_session_elapsed(), 1)})


def first_upgrade() -> None:
    _write("first_upgrade", {"session_time_s": round(_session_elapsed(), 1)})


def first_manager(name: str) -> None:
    _write("first_manager", {"name": name, "session_time_s": round(_session_elapsed(), 1)})


def first_territory() -> None:
    _write("first_territory", {"session_time_s": round(_session_elapsed(), 1)})


def first_rival_defeat() -> None:
    _write("first_rival_defeat", {"session_time_s": round(_session_elapsed(), 1)})


def first_operation() -> None:
    _write("first_operation", {"session_time_s": round(_session_elapsed(), 1)})


def first_influence(amount: int) -> None:
    _write("first_influence", {"influence": amount, "session_time_s": round(_session_elapsed(), 1)})


def rank_up(rank: str, influence: int) -> None:
    _write("rank_up", {"rank": rank, "influence": influence})


def prestige(count: int, influence_gain: int, total_influence: int,
             lifetime: float, session_time: float) -> None:
    _write("prestige", {
        "count": count,
        "influence_gain": influence_gain,
        "total_influence": total_influence,
        "lifetime_earnings": float(lifetime),
        "time_to_prestige_s": round(float(session_time), 1),
    })


def manager_hired(name: str) -> None:
    _write("manager_hired", {"name": name})


def territory_captured(name: str, perk_key: str) -> None:
    _write("territory_captured", {"name": name, "perk": perk_key})


def offline_return(gain: float, secs_away: float, capped: bool) -> None:
    _write("offline_return", {
        "gain": float(gain), "secs_away": round(float(secs_away), 1), "capped": bool(capped)})


def daily_reward(streak: int, reward: float) -> None:
    _write("daily_reward", {"streak": streak, "reward": float(reward)})


def _near_prestige(state) -> bool:
    """True if the player was within ~20% of their next prestige earnings gate
    when the session ended — a strong 'almost hooked, came back?' churn marker."""
    try:
        import src.prestige as prestige
        need = prestige.prestige_earnings_required(state)
        have = float(getattr(state, "lifetime_earnings", 0.0) or 0.0)
        return need > 0 and 0.80 * need <= have < need
    except Exception:
        return False


# ─── Push-notification hooks ──────────────────────────────────────────────────
# These are fire-points only. The game calls them at the right moment; a backend
# or OS notification layer reads them from the log (or overrides _push_deliver).
# On mobile you'd replace _push_deliver with the platform SDK call.

def _push_deliver(title: str, body: str, payload: dict) -> None:
    """Stub: log the push as a special analytics event.

    Replace this function (or monkey-patch it) with a platform-specific
    implementation (APNs, FCM, local notification SDK) when you have a backend.
    The payload is always a plain dict so it can be JSON-serialised for any system.
    """
    _write("push_notification", {
        "title": title,
        "body": body,
        "payload": payload,
    })


def push_offline_idle(secs_idle: float, projected_earnings: float,
                      prestige_pct: float) -> None:
    """Fire when the player has been away long enough to warrant a return hook.

    secs_idle         – seconds since last session.
    projected_earnings – cash earned while offline (at cap).
    prestige_pct      – how close (0–1) they are to next prestige.
    """
    hours = int(secs_idle) // 3600
    mins  = (int(secs_idle) % 3600) // 60
    away  = f"{hours}h {mins}m" if hours else f"{mins}m"

    if prestige_pct >= 0.85:
        title = "Your empire is ready to evolve"
        body  = f"You've been away {away}. You're almost at Prestige — claim it now."
    elif projected_earnings > 0:
        from src.theme import format_number
        title = "Your empire kept running"
        body  = f"Away for {away}. +{format_number(projected_earnings)} waiting for you."
    else:
        title = "Your city misses you"
        body  = f"The empire hasn't moved in {away}. Time to check in."

    _push_deliver(title, body, {
        "trigger": "offline_idle",
        "secs_idle": round(secs_idle, 0),
        "projected_earnings": round(projected_earnings, 2),
        "prestige_pct": round(prestige_pct, 3),
    })


def push_near_prestige(lifetime: float, needed: float) -> None:
    """Fire when the player reaches 90% of their prestige gate in a session.

    This fires in-session (not as a background push); it's here so a backend
    can queue a delayed notification: "You were so close! Finish your prestige."
    """
    from src.theme import format_number
    title = "You're almost there"
    body  = (f"Just {format_number(needed - lifetime)} more and you can Prestige. "
             "Don't leave now.")
    _push_deliver(title, body, {
        "trigger": "near_prestige",
        "lifetime": round(lifetime, 2),
        "needed": round(needed, 2),
        "pct": round(lifetime / max(needed, 1), 3),
    })


def push_rival_threat(rival_name: str, aggression: float) -> None:
    """Fire when a rival reaches high aggression — good urgency re-engagement hook."""
    title = f"{rival_name} is making moves"
    body  = "A rival syndicate is expanding while you're away. Retaliate."
    _push_deliver(title, body, {
        "trigger": "rival_threat",
        "rival": rival_name,
        "aggression": round(aggression, 2),
    })


def push_daily_reminder(streak: int) -> None:
    """Fire ~20–22 hours after last session to protect a daily streak."""
    if streak >= 7:
        body = f"Day {streak} streak — don't let it break now."
    elif streak >= 3:
        body = f"{streak}-day streak at risk. Log in and claim your daily bonus."
    else:
        body = "Your daily bonus is waiting. Claim it to build your streak."
    _push_deliver("Don't break the streak", body, {
        "trigger": "daily_reminder",
        "streak": streak,
    })
