class_name GameEvents
extends Node

enum ShapeKind { CUBE, PYRAMID, SPHERE }
enum RunState { READY, TUTORIAL, RUNNING, CRASHED, RESULTS, PAUSED }
enum JudgmentKind { PERFECT, NEAR_MISS, MISS }

signal run_started(seed: int)
signal run_restarted(seed: int)
signal run_paused(paused: bool)
signal run_failed(score: int, high_score: int)
signal lane_changed(lane: int)
signal shape_changed(shape: ShapeKind)
signal gate_telegraphed(lane: int, shape: ShapeKind, time_to_impact: float)
signal gate_judged(kind: JudgmentKind, points: int)
signal combo_changed(combo: int, multiplier: int)
signal speed_changed(speed: float, normalized_intensity: float)

static func shape_name(kind: ShapeKind) -> String:
	match kind:
		ShapeKind.CUBE:
			return "CUBE"
		ShapeKind.PYRAMID:
			return "PYRAMID"
		ShapeKind.SPHERE:
			return "SPHERE"
	return "UNKNOWN"

static func shape_glyph(kind: ShapeKind) -> String:
	match kind:
		ShapeKind.CUBE:
			return "□"
		ShapeKind.PYRAMID:
			return "△"
		ShapeKind.SPHERE:
			return "○"
	return "?"
