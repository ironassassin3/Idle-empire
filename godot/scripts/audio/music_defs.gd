extends RefCounted
class_name MusicDefs
## Data-only scaffold for procedural music — scales, motifs, tempo bands.
## See MUSIC_ARCHITECTURE.md. No PCM generation here (M1+ in AudioManager / sequencer).

enum MusicMode {
	MENU,
	PLAYING_AMBIENT,
	PLAYING_TENSION,
	PRESTIGE_CLIMAX,
	OFFLINE_RETURN,
}

enum MusicTempo {
	LARGO = 56,
	ANDANTE = 72,
	MODERATO = 96,
	ALLEGRO = 108,
	PRESTO = 132,
}

enum DistrictMotif {
	HOME,
	CASH,
	OPS,
	SMUGGLE,
	POLITICS,
	RESIDENTIAL,
	COMMERCIAL,
	INDUSTRIAL,
	GOVERNMENT,
}

# Semitone offsets from root (12-TET).
const SCALE_NATURAL_MINOR: PackedInt32Array = PackedInt32Array([0, 2, 3, 5, 7, 8, 10])
const SCALE_PHRYGIAN: PackedInt32Array = PackedInt32Array([0, 1, 3, 5, 7, 8, 10])
const SCALE_DORIAN: PackedInt32Array = PackedInt32Array([0, 2, 3, 5, 7, 9, 10])
const SCALE_MINOR_BLUES: PackedInt32Array = PackedInt32Array([0, 3, 5, 6, 7, 10])
const SCALE_MAJOR_FANFARE: PackedInt32Array = PackedInt32Array([0, 2, 4, 5, 7, 9, 11])

# Interval sequences (semitones from phrase start) — simplified film leitmotifs.
const MOTIF_GODFATHER: PackedInt32Array = PackedInt32Array([0, 3, 5, 3, 0, -2, 0])
const MOTIF_WALTZ_BASS: PackedInt32Array = PackedInt32Array([0, 7, 12])
const MOTIF_MANDOLIN_ARP: PackedInt32Array = PackedInt32Array([0, 4, 7, 4])
const MOTIF_SCARFACE_RISE: PackedInt32Array = PackedInt32Array([0, 4, 7, 12, 12])
const MOTIF_SOPRANOS_HOOK: PackedInt32Array = PackedInt32Array([0, 3, 5, 6, 5, 3, 0])
const MOTIF_RAID_STAB: PackedInt32Array = PackedInt32Array([0, 1, 0])

# Pad roots (Hz) — align with audio_manager._ambient noir drone.
const ROOT_A2: float = 110.0
const ROOT_E3: float = 164.81
const ROOT_A3: float = 220.0
const ROOT_C4: float = 261.63

const AMBIENT_ROOTS: PackedFloat32Array = PackedFloat32Array([ROOT_A2, ROOT_E3, ROOT_A3])
const AMBIENT_WEIGHTS: PackedFloat32Array = PackedFloat32Array([1.0, 0.55, 0.4])

# Default loop length (seconds) — whole-cycle LFO math in AudioManager.
const AMBIENT_LOOP_SEC: float = 4.0
const AMBIENT_VOL: float = 0.22

static func district_motif_for_type(district_type: String) -> DistrictMotif:
	match district_type:
		"residential":
			return DistrictMotif.RESIDENTIAL
		"commercial":
			return DistrictMotif.COMMERCIAL
		"industrial":
			return DistrictMotif.INDUSTRIAL
		"government":
			return DistrictMotif.GOVERNMENT
		_:
			return DistrictMotif.HOME

static func scale_for_district(motif: DistrictMotif) -> PackedInt32Array:
	match motif:
		DistrictMotif.POLITICS, DistrictMotif.GOVERNMENT:
			return SCALE_DORIAN
		DistrictMotif.OPS, DistrictMotif.INDUSTRIAL, DistrictMotif.SMUGGLE:
			return SCALE_PHRYGIAN
		DistrictMotif.CASH, DistrictMotif.COMMERCIAL:
			return SCALE_MINOR_BLUES
		_:
			return SCALE_NATURAL_MINOR

static func motif_intervals_for_district(motif: DistrictMotif) -> PackedInt32Array:
	match motif:
		DistrictMotif.CASH:
			return MOTIF_GODFATHER
		DistrictMotif.SMUGGLE:
			return MOTIF_SCARFACE_RISE
		DistrictMotif.POLITICS:
			return MOTIF_RAID_STAB
		DistrictMotif.OPS, DistrictMotif.INDUSTRIAL:
			return MOTIF_MANDOLIN_ARP
		DistrictMotif.COMMERCIAL:
			return MOTIF_SOPRANOS_HOOK
		_:
			return MOTIF_WALTZ_BASS
