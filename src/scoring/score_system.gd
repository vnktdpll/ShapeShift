class_name ScoreSystem
extends RefCounted

signal changed(score: int, combo: int, multiplier: int)
signal milestone(combo: int)

var score: int = 0
var combo: int = 0
var multiplier: int = 1
var best_combo: int = 0
var near_misses: int = 0

func reset() -> void:
	score = 0
	combo = 0
	multiplier = 1
	best_combo = 0
	near_misses = 0
	changed.emit(score, combo, multiplier)

func register_judgment(kind: GameEvents.JudgmentKind, speed_intensity: float = 0.0) -> int:
	match kind:
		GameEvents.JudgmentKind.PERFECT:
			combo += 1
			best_combo = maxi(best_combo, combo)
			multiplier = clampi(1 + combo / 5, 1, 8)
			var points := int(round(100.0 * float(multiplier) * (1.0 + speed_intensity * 0.5)))
			score += points
			if combo % 5 == 0:
				milestone.emit(combo)
			changed.emit(score, combo, multiplier)
			return points
		GameEvents.JudgmentKind.NEAR_MISS:
			near_misses += 1
			combo += 1
			best_combo = maxi(best_combo, combo)
			multiplier = clampi(1 + combo / 5, 1, 8)
			var points := 60 * multiplier
			score += points
			changed.emit(score, combo, multiplier)
			return points
		GameEvents.JudgmentKind.MISS:
			combo = 0
			multiplier = 1
			changed.emit(score, combo, multiplier)
	return 0
