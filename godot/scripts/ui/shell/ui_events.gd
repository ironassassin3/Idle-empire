extends Node
## UiEvents autoload — typed UI signal hub (UI_OVERHAUL_ARCHITECTURE.md §5).
## Owns signals only; never mutates state. Shell chrome talks through here so
## masthead / rail / dock / screens stay decoupled from each other.

## Nav dock or code requested a primary tab ("bldgs" / "upgrs" / "mgrs" / "turf" / "stats").
signal tab_requested(tab_id: String)
## Turf screen subtab ("turf" / "rivals" / "crew" / "ops").
signal subtab_requested(tab_id: String)
## Modal surface requested ("config" / "prestige" / "dragon" / "gambling").
signal overlay_requested(kind: String)
## AttentionDirector publishes the current rail item ({} = empty slot).
signal attention_changed(item: Dictionary)
## AttentionDirector publishes per-tab READY badge counts {tab_id: int}.
signal badges_changed(counts: Dictionary)
## Content sheet snapped to a new state (ContentDeck.SheetState).
signal sheet_state_changed(state: int)
## Rail item of this kind was acted on (tapped) — lets AttentionDirector
## retire one-shot ambient offers (e.g. "compact_offer") without a direct ref.
signal rail_action(kind: String)
## A building was bought — carries WHICH one, so the city, its row, and the
## masthead can all react to the same addressed beat.
signal building_purchased(key: String)
## Heat crossed a band boundary. level: 0 calm, 1 warn (>=60), 2 critical (>=85).
signal heat_crossed(level: int)
## A district changed hands. holder: "player" | "rival" | "neutral".
signal district_changed(idx: int, holder: String)
