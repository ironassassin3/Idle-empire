# Music Architecture — Criminal Empire (8-bit / chiptune)

> **Policy:** All music and SFX are **code-generated** per [`ART_POLICY.md`](ART_POLICY.md). No Suno, Udio, AI libraries, or external audio clips. This document is the creative + technical blueprint; implementation stays in GDScript using existing repo tools (`audio_manager.gd`, `sfxr.gd`, `src/sound.py` lab reference).

**Status:** Architecture (M0). Current ship build has a single procedural ambient drone (`_ambient()` in `audio_manager.gd`). Phases M1–M4 below extend that stack without new dependencies.

---

## 1. Creative brief — noir-rustic criminal empire in 8-bit

Criminal Empire is an idle crime syndicate sim with **Italian-American / Sicilian mafia folklore** filtered through **retro handheld constraints**: limited channels, square-wave “mandolin,” triangle bass, noise grit, and pattern-based loops—not orchestral recordings.

**Sonic identity (one sentence):** *A smoky back-room waltz overheard through a broken arcade speaker—family nostalgia, cold power, and paranoia in three voices.*

**Creative pillars:**

| Pillar | Source genre | 8-bit expression |
|--------|--------------|------------------|
| **Famiglia** | Godfather / Once Upon a Time in America | Slow minor waltz, trumpet-like square lead, mandolin tremolo arps |
| **Wiseguy hustle** | Goodfellas / Casino / Scarface | Faster pulse, walking bass, syncopated noise hi-hats, rising synth stabs |
| **Suburban dread** | The Sopranos | Downtempo blues shuffle on triangle + muted square, sparse melody |
| **Neapolitan grit** | Gomorrah | Phrygian color, darker bass, less romance, more tension |
| **Empire idle** | Game loop | Seamless loops, low CPU, layers that crossfade—not full songs that fight SFX |

**What we are *not* doing:** Licensing or mimicking Nino Rota recordings, Alabama 3, Morricone stems, or Scorsese needle-drops. We extract **interval habits, instrument clichés, and mood palettes**, then rebuild them from oscillators.

**Default mix target:** Music ~25% of master (current `_music_linear` default); SFX pool on separate bus once M1 lands. Music never masks milestone SFX (`prestige`, `rival`, `territory`).

---

## 2. Reference research — iconic works → sonic traits

### 2.1 Works surveyed (8 primary + 2 adjacent)

| Work | Composer / music direction | Core sonic traits |
|------|---------------------------|-------------------|
| **The Godfather** (1972) | Nino Rota | Solo **trumpet** opening motif; **mandolin / accordion / guitar** “café” color inside orchestra; **Godfather Waltz** leitmotif that darkens as Michael hardens; operatic family tragedy |
| **The Godfather Part II** (1974) | Nino Rota | Same leitmotif **transformed**—nostalgic Sicily vs cold America; waltz tempo, minor melancholy |
| **Once Upon a Time in America** (1984) | Ennio Morricone | **Pan flute / whistle** nostalgia, **mandolin**, slow **waltz**, decades-long melancholy |
| **Goodfellas** (1990) | Scorsese curated (rock/R&B) | **Diegetic** classics drive paranoia montages; baritone sax, bass riff anxiety; music = character interior state, not neutral score |
| **Casino** (1995) | Scorsese curated + score accents | Rock irony strips glamour; decadent pulse; violence underscored by **dissonance** or sudden silence |
| **The Sopranos** (1999–2007) | Alabama 3 + curated | **“Woke Up This Morning”**—bluesy menace, downtempo; Rota-like strings quoted in later seasons; suburban noir |
| **Scarface** (1983) | Giorgio Moroder | **Synth-rock** excess; “Push It to the Limit” = rising arpeggio ambition; Miami Italo-American power fantasy |
| **Gomorrah** (2014–2021) | Contemporary Italian artists | **Neorealist grit**—electronic pulse, rap, regional dialect culture; less romantic, more procedural violence |
| **The Untouchables** (1987) | Ennio Morricone | Staccato **brass** tension, martial snare energy, righteous-vs-corrupt chase |
| **Peaky Blinders** (2013–2022) *(adjacent)* | Nick Cave “Red Right Hand” | **Outlaw dirge**—minimal pulse, baritone threat; useful parallel for rival/turf dread |

### 2.2 Extracted clichés (cross-media)

**Instrumentation (orchestral/film → chiptune stand-in):**

| Film cliché | Emotional read | 8-bit channel |
|-------------|----------------|---------------|
| Trumpet solo | Omen, authority, mourning | Square wave, soft duty (~25%), vibrato |
| Mandolin tremolo | Sicily, romance, folk | Fast **arpeggio** on square (3–4 note cycle) |
| Accordion | Street café, comedy-tragedy | Detuned second square (+12 cents) |
| Upright bass / walking jazz | Noir city, night | Triangle wave, low register |
| Piano chord stabs | Domestic tension | Short square chords, staccato envelope |
| Noir jazz combo | Urban realism | Triangle bass + noise “brush” + sparse square |
| Synth lead (Scarface) | Hubris, 80s power | Square with fast pitch ramp (`sfxr` freq ramp) |
| Staccato brass (Untouchables) | Raid / chase | Square stabs, noise snare |

**Mood palettes:**

| Mood | When in Criminal Empire | Tempo (BPM) | Mode / color |
|------|-------------------------|-------------|--------------|
| **Nostalgia** | Early run, residential districts, offline return | 56–72 | Natural minor, slow waltz (3/4) |
| **Power** | Downtown, City Hall, high rank | 80–96 | Minor with raised leading tone |
| **Tension** | Heat ≥ 60%, raids, rival tab | 100–120 | Phrygian / half-dim color |
| **Melancholy** | Post-prestige wipe, defeat | 48–64 | Minor, descending motifs |
| **Celebration** | Territory capture, rank-up | 96–112 | Major fanfare fragment |
| **Paranoia** | Goodfellas-style montage energy | 120–140 | Minor + syncopated bass |

**Leitmotif patterns (film → game):**

| Film pattern | Game adaptation |
|--------------|-----------------|
| Character theme (Michael’s arc) | **Rank tier** motif variant—same intervals, darker duty/wave as rank rises |
| Location theme (Sicily vs NYC) | **District-type** motifs (residential / commercial / industrial / government / strategic) |
| Recurring waltz | **Ambient loop** pulse in 3/4 LFO + bass |
| Stinger before violence | **Heat raid** noise swell + 1-bar square stab |
| Prestige / saga reset | **Fanfare** arpeggio (already in `prestige` SFX—extend for music layer) |

### 2.3 8-bit constraint mapping (NES / Game Boy mindset)

| Constraint | Implication for this game |
|------------|---------------------------|
| 3–4 simultaneous tones | Ambient = bass + pad + one melodic fragment max |
| Square + triangle + noise | Map directly to Godot sine/square/noise synthesis (see `_ambient`, `sfxr` wave types) |
| No reverb (or fake it) | Use phaser in `sfxr` or slow amplitude LFO for “room” |
| Arpeggios instead of chords | Mandolin, harp, Scarface synth runs |
| Loop ≤ 8–16 bars | Match `_ambient(4.0)` pattern; extend to 8s or 16s with whole-cycle math |
| One music stream on mobile | **Single `AudioStreamPlayer`** + crossfade at loop boundary OR pre-mixed composite stream |
| SFX priority | Music bus ducking optional later; milestone SFX stay on SFX bus |

---

## 3. Reference matrix — work → trait → 8-bit adaptation

Constant names below reference [`music_defs.gd`](godot/scripts/audio/music_defs.gd). †-marked rows are not yet in the scaffold — add them in the phase noted.

| Work | Sonic trait | 8-bit adaptation | Const |
|------|-------------|------------------|-------|
| Godfather | Trumpet omens in minor | Square lead motif @ ~261 Hz (`ROOT_C4`) base, 3/4, vibrato ~5 Hz | `MOTIF_GODFATHER` |
| Godfather | Mandolin café texture | 16th-note triad arp on square, duty ~12% | `MOTIF_MANDOLIN_ARP` |
| Godfather Part II | Theme darkens over time | Same motif; increase noise mix + lower duty as `heat` rises | (reuse `MOTIF_GODFATHER`) |
| Once Upon a Time in America | Nostalgic waltz | Triangle bass on beats 1–2–3; slow LFO on pad (current `_ambient` swell) | `MOTIF_WALTZ_BASS` |
| Goodfellas | Paranoid bass riff | Triangle walking pattern at `ALLEGRO` (108 BPM) | `MOTIF_WALK_BASS` † (M3) |
| Casino | Ironic rock pulse | Noise channel hi-hat grid + square off-beat stabs | — (sequencer rows, M2) |
| Sopranos | Bluesy menace | `SCALE_MINOR_BLUES` lead, triangle root, sparse rests | `MOTIF_SOPRANOS_HOOK` |
| Scarface | Rising synth ambition | `sfxr` square + `p_freq_ramp` up; rising arp | `MOTIF_SCARFACE_RISE` |
| Gomorrah | Cold procedural violence | `SCALE_PHRYGIAN` bass, minimal melody, noise forward | (scale, no motif) |
| Untouchables | Raid staccato | 1-bar square + noise burst (share timbre with `error` SFX) | `MOTIF_RAID_STAB` |
| Peaky Blinders | Outlaw dirge pulse | Low square pulse 2+2 bars; use on Rivals tab | — (M3 tension) |

---

## 4. Layer stack — maps to game states & tabs

```
┌─────────────────────────────────────────────────────────────┐
│  L4  Prestige climax / rank fanfare (one-shot overlay)      │
├─────────────────────────────────────────────────────────────┤
│  L3  Tension stingers (raid, turf contest, rival overlay)   │
├─────────────────────────────────────────────────────────────┤
│  L2  District theme modifier (district_type leitmotif)       │
├─────────────────────────────────────────────────────────────┤
│  L1  Ambient loop (base pad + waltz bass) — always under    │
├─────────────────────────────────────────────────────────────┤
│  L0  Menu theme (title / main menu — distinct hook)          │
└─────────────────────────────────────────────────────────────┘
```

### 4.1 Layer → game mapping

| Layer | Content | Trigger | Godot hook (proposed) |
|-------|---------|---------|------------------------|
| **L0 Menu** | Hook + noir waltz (8 bars) | Main menu / boot | `MainMenu` or boot scene → `AudioManager.set_music_mode(MENU)` |
| **L1 Ambient** | A2/E3 pad + 3/4 swell (exists) | Default gameplay | `PLAYING_AMBIENT` — current `_music_player` |
| **L2 District** | District-type motif mixed into loop | Dominant owned `district_type` OR active tab context | `GameState.territories` + `TerritorySystem`; tab `TURF` boosts turf motif |
| **L3 Tension** | Noise swell + staccato; faster bass | `heat >= 60`, contested territory, `Tab.RIVALS`, syndicate combat event | `GameState.heat`, `HeatSystem.RAID_THRESHOLD`, `game_screen._tab` |
| **L4 Climax** | Prestige / rank fanfare | `prestiged` signal, rank-up overlay | `GameState.prestiged`, existing `rankup` / `prestige` SFX + music swell |
| **Offline return** | Soft nostalgia variant | Return bonus overlay | `GameState` return fields / save load |

### 4.2 Tab affinity (sub-mix bias when layer L2 is active)

| Tab | `game_screen.gd` `Tab` | Musical bias |
|-----|------------------------|----------------|
| Bldgs / Upgrs / Mgrs | `BLDGS`, `UPGRS`, `MGRS` | Ambient + empire bass (neutral minor) |
| Turf | `TURF` | District leitmotif of selected / majority district |
| Rivals | `RIVALS` | Tension L3 + outlaw dirge pulse |
| Crew / Ops | `CREW`, `OPS` | Industrial / operations motif (sharper square) |
| Stats / Config | `STATS`, `CONFIG` | Strip melody; ambient only |

### 4.3 Strategic districts (named themes)

The five `TerritorySystem.STRATEGIC_NAMES` anchor L2 hooks:

| District | Motif key | Mode | Character |
|----------|-----------|------|-----------|
| South Side | `HOME` | Natural minor | Folk waltz, warm |
| Downtown | `CASH` | Minor + major 3rd lift | Walking bass, “money” staccato |
| Industrial District | `OPS` | Phrygian touches | Mechanical noise grid |
| Waterfront | `SMUGGLE` | Minor | Wave-like arp, noise spray |
| City Hall | `POLITICS` | Dorian | Cold authority, low trumpet motif |

Residential / commercial / government **district_types** use shared templates from `music_defs.gd`.

---

## 5. Technical architecture — `AudioManager` implementation plan

### 5.1 Current state (as of P6)

| Component | Location | Behavior |
|-----------|----------|----------|
| SFX pool | `audio_manager.gd` | 8× `AudioStreamPlayer`, round-robin, **bus = Master** |
| Music player | `_music_player` | Single loop, `_ambient(4.0, 0.22)`, **bus = Master** |
| SFX generation | `sfxr.gd` | One-shots at 44100 Hz, startup bake |
| Ambient generation | `_ambient()` | Sine pad 22050 Hz, seamless loop |
| Volume | `apply_from_state(GameState)` | `master × sfx_volume`, `master × music_volume` |
| Headless | `_is_headless()` | No audio init |
| Game hooks | `game_screen.gd` | SFX only (`play`, `cue_for_notification`); **no music state changes** |

**Already scaffolded in `music_defs.gd` (M0):** `MusicMode` / `MusicTempo` / `DistrictMotif` enums; all `SCALE_*` and `MOTIF_*` constants; `AMBIENT_ROOTS` / `AMBIENT_WEIGHTS` / `AMBIENT_LOOP_SEC` / `AMBIENT_VOL`; and the data→music mapping helpers `district_motif_for_type()`, `scale_for_district()`, `motif_intervals_for_district()`. M2 consumes these — the mapping layer does **not** need to be rebuilt.

**Gaps for M1:**
- P6 report mentions a Music bus; code still routes both pools to **Master**. M1 adds buses (§5.2).
- `_ambient()` hardcodes `freqs := [110.0, 165.0, 220.0]` / `weights := [1.0, 0.55, 0.4]`; the scaffold already exposes these as `AMBIENT_ROOTS` (note: `ROOT_E3 = 164.81`, not `165.0`) and `AMBIENT_WEIGHTS`. M1 should consume the constants and reconcile the 164.81/165.0 drift.

### 5.2 Target bus layout

```
Master
├── Music    ← _music_player (+ optional _music_layer_player)
├── SFX      ← _players[] pool
└── (UI optional future)
```

Configure in `default_bus_layout.tres` or `AudioServer` at `AudioManager._ready()`:

- Music bus: slight low-pass feel via `AudioEffectLowPassFilter` (optional, mobile-cheap)
- SFX bus: full band
- Ducking (M3 optional): Music −3 dB for 400 ms when `play("prestige")` etc.

### 5.3 Procedural generation approach

**Principle (match P6):** Bake all streams in `_build_streams()` at startup. **Zero per-frame allocation** during gameplay.

| Stream type | Generator | Notes |
|-------------|-----------|-------|
| Long loops | New `music_sequencer.gd` (or methods on `AudioManager`) | Pattern rows from `music_defs.gd`; sum channels into `PackedInt32Array` → `_make_stream()` (exists), then set loop fields like `_ambient()` |
| One-shot stingers | `sfxr.gd` | Raids, turf wins—reuse `Sfxr.render` + short params |
| Existing ambient | `_ambient()` | M1 upgrades frequencies to `AMBIENT_ROOTS` from defs |

**Sequencer sketch (M2):**

```gdscript
# Pseudocode — not shipped yet. Mirrors _ambient()'s loop-field pattern.
func _render_pattern(rows: Array, bpm: int, bars: int, beats_per_bar: int) -> AudioStreamWAV:
    var beat_s := 60.0 / float(bpm)
    var n := int(SAMPLE_RATE * bars * beats_per_bar * beat_s)  # whole-cycle, no boundary click
    var samples := PackedInt32Array()
    samples.resize(n)
    # For each row event: square/triangle/noise sample per channel, sum, clamp to ±32767
    var stream := _make_stream(samples)         # reuse existing helper
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = n
    return stream
```

**Wave sources:**

| Wave | GDScript |
|------|----------|
| Sine pad | `sin(TAU * freq * t)` — current `_ambient` |
| Square lead | `sign(sin(...))` or sfxr square duty |
| Triangle bass | Integrated square or `asin(sin(...))` approximation |
| Noise grit | `RandomNumberGenerator` pre-baked buffer per loop |

**sfxr integration:**

- **SFX:** unchanged (blips, fanfares).
- **Music stingers:** `preset_powerup` + overrides for raid/stinger (short decay).
- **Not for full loops:** `MAX_SECONDS = 4.0` cap; loops use dedicated sequencer.

### 5.4 Music state machine

Proposed enum in `music_defs.gd` → driven by `AudioManager`:

```
                    ┌──────────┐
                    │   MENU   │
                    └────┬─────┘
                         │ enter game
                         ▼
              ┌────────────────────┐
              │  PLAYING_AMBIENT   │◄────┐
              └─────────┬──────────┘     │
                        │ heat < 60      │ heat drops
                        ▼                │
              ┌────────────────────┐     │
              │  PLAYING_TENSION   │─────┘
              └─────────┬──────────┘
                        │ prestige confirm
                        ▼
              ┌────────────────────┐
              │ PRESTIGE_CLIMAX    │ → one-shot, then PLAYING_AMBIENT
              └────────────────────┘

OFFLINE_RETURN: variant ambient (nostalgia motif) on save load once, 30s then ambient
DISTRICT_SHIFT: crossfade L2 when dominant district_type changes (debounced 2s)
```

**Proposed API:**

```gdscript
func set_music_mode(mode: int) -> void
func update_music_context(ctx: Dictionary) -> void  # heat, tab, district_type, contested
func _crossfade_to(stream_key: String, duration: float = 1.5) -> void
```

**Call sites (implementation):**

| Event | Caller |
|-------|--------|
| Boot / menu | Main scene |
| Every 1s while playing | `game_screen._process` or `GameState` tick — debounced context |
| `heat` crosses 60 | `HeatSystem.update` message or `game_screen` heat bar |
| Tab change | `game_screen._set_tab` |
| Prestige | `GameState.prestiged` → `game_screen` listener |
| Load game | `SaveManager` after `GameState.load` |

### 5.5 File layout (target)

```
godot/scripts/audio/
  music_defs.gd      # scales, motifs, tempo enums (data)
  music_sequencer.gd # pattern → PCM (M2)
  sfxr.gd            # existing
godot/scripts/autoload/
  audio_manager.gd   # buses, players, state machine, bake at ready
```

---

## 6. 8-bit motif library — data constants

Canonical definitions live in [`godot/scripts/audio/music_defs.gd`](godot/scripts/audio/music_defs.gd).

### 6.1 Scales (semitone offsets from root MIDI)

| Const | Intervals | Use |
|-------|-----------|-----|
| `SCALE_NATURAL_MINOR` | 0,2,3,5,7,8,10 | Godfather nostalgia, home turf |
| `SCALE_PHRYGIAN` | 0,1,3,5,7,8,10 | Gomorrah grit, industrial |
| `SCALE_DORIAN` | 0,2,3,5,7,9,10 | City Hall politics |
| `SCALE_MINOR_BLUES` | 0,3,5,6,7,10 | Sopranos menace |
| `SCALE_MAJOR_FANFARE` | 0,2,4,5,7,9,11 | Territory / rank stingers |

### 6.2 Core motifs (interval sequences from root)

| Const | Semitones | Origin |
|-------|-----------|--------|
| `MOTIF_GODFATHER` | 0, +3, +5, +3, 0, −2, 0 | Trumpet leitmotif simplification |
| `MOTIF_WALTZ_BASS` | 0, +7, +12 (per bar) | 3/4 oom-pah-pah (root–fifth–octave) |
| `MOTIF_MANDOLIN_ARP` | 0, +4, +7, +4 | Mandolin tremolo (triad cycle) |
| `MOTIF_SCARFACE_RISE` | 0, +4, +7, +12, +12 | Rising ambition |
| `MOTIF_SOPRANOS_HOOK` | 0, +3, +5, +6, +5, +3, 0 | Bluesy descent |
| `MOTIF_RAID_STAB` | 0, +1, 0 | Untouchables raid (staccato) |

### 6.3 Tempo bands (`MusicTempo` enum)

| Enum | BPM | Use |
|------|-----|-----|
| `LARGO` | 56 | Melancholy / offline return |
| `ANDANTE` | 72 | Default ambient waltz |
| `MODERATO` | 96 | Downtown / empire growth |
| `ALLEGRO` | 108 | Turf / rivals tension |
| `PRESTO` | 132 | Scarface / frenzy overlay |

### 6.4 Root frequencies (Hz at A=440)

Defined in `music_defs.gd`. `AMBIENT_ROOTS = [ROOT_A2, ROOT_E3, ROOT_A3]`, `AMBIENT_WEIGHTS = [1.0, 0.55, 0.4]`.

- `ROOT_A2 = 110.0` — bass / pad
- `ROOT_E3 = 164.81` — **drift:** `_ambient()` hardcodes `165.0`; reconcile in M1
- `ROOT_A3 = 220.0`
- `ROOT_C4 = 261.63` — melodic center for motifs

### 6.5 Mapping API (already in `music_defs.gd`)

M2 consumes these `static` helpers — do not re-derive the mapping:

| Function | In → out |
|----------|----------|
| `district_motif_for_type(district_type: String)` | `"residential"`/`"commercial"`/… → `DistrictMotif` (defaults `HOME`) |
| `scale_for_district(motif: DistrictMotif)` | `DistrictMotif` → `SCALE_*` (Dorian for politics/gov, Phrygian for ops/industrial/smuggle, blues for cash/commercial, else natural minor) |
| `motif_intervals_for_district(motif: DistrictMotif)` | `DistrictMotif` → `MOTIF_*` interval array |

> `_ambient()` still uses local literals `[110.0, 165.0, 220.0]` / `[1.0, 0.55, 0.4]` instead of these constants. M1 first task: swap to `MusicDefs.AMBIENT_ROOTS` / `AMBIENT_WEIGHTS` so there is a single source of truth.

---

## 7. Implementation phases

| Phase | Scope | Deliverable | Depends on |
|-------|-------|-------------|------------|
| **M0** | Architecture | This document + `music_defs.gd` scaffold | — |
| **M1 Ambient upgrade** | Music/SFX buses; `_ambient` uses defs; optional 8s waltz bass | PR: `audio_manager.gd`, `default_bus_layout` | M0 |
| **M2 District leitmotifs** | `music_sequencer.gd`; L2 mix by `district_type`; tab bias | 4 district templates + 5 strategic | M1 |
| **M3 Tension layers** | Heat ≥ 60 crossfade; Rivals tab pulse; raid stinger | `PLAYING_TENSION` state | M1 |
| **M4 Prestige climax** | Music swell under `prestige` SFX; menu theme L0 | `PRESTIGE_CLIMAX`, boot menu | M1 |

**Lab parity (optional):** Port motif constants to `src/sound.py` for pygame A/B — not required for ship.

**Verification:**

```bash
python sim_godot_soak.py --godot "<path>"   # must stay zero SCRIPT ERROR
# Manual: DEVICE_TEST_CHECKLIST.md §A — music layers audible per state
```

---

## 8. Performance & mobile

| Rule | Rationale |
|------|-----------|
| Single music stream (M1–M3) | One `AudioStreamPlayer`; composite loops pre-mixed |
| Second player only for crossfade (M2+) | Brief overlap ≤ 2s; free after fade |
| Bake at `_ready()` | Same as SFX pool pattern |
| Loop lengths: 4s, 8s, or 16s | Whole-cycle LFO / bar math avoids boundary clicks (existing `_ambient` comment) |
| Sample rate 22050 for music | Matches `_SAMPLE_RATE`; sfxr stays 44100 for SFX |
| Cap simultaneous voices in sequencer ≤ 4 | Mobile-safe mix |
| Headless: no bake | `is_enabled() == false` |
| No `render()` in `_process` | Context updates only swap pre-baked `stream` refs |

**Memory estimate:** 8s stereo 16-bit @ 22050 ≈ 350 KB per loop; 10 variants ≈ 3.5 MB — acceptable for mobile idle.

---

## 9. Policy compliance

| Requirement | How this architecture complies |
|-------------|----------------------------------|
| No generative AI audio | All PCM from GDScript math + `sfxr` |
| No external music files | `AudioStreamWAV` from code only |
| No AI API dependencies | Zero new packages |
| Documented in ART_POLICY | §3 procedural audio; this doc extends P6 music scope |
| Agent workflow | Read `ART_POLICY.md` before M1+ implementation |

---

## 10. Related repo files

| File | Role |
|------|------|
| [`godot/scripts/autoload/audio_manager.gd`](godot/scripts/autoload/audio_manager.gd) | Ship audio autoload |
| [`godot/scripts/audio/sfxr.gd`](godot/scripts/audio/sfxr.gd) | Retro one-shot synth |
| [`godot/scripts/audio/music_defs.gd`](godot/scripts/audio/music_defs.gd) | Motif/scales data |
| [`src/sound.py`](src/sound.py) | pygame lab — arpeggio primitive reference |
| [`godot/scripts/ui/game_screen.gd`](godot/scripts/ui/game_screen.gd) | SFX hooks; future music context |
| [`P6_REPORT.md`](P6_REPORT.md) | Audio & feel delivery log |
| [`SHIP_ARCHITECTURE.md`](SHIP_ARCHITECTURE.md) | Autoload / headless patterns |

---

*Document version: M0 — 2026-06-19*
