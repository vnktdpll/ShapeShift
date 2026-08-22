class_name SparkFxProfile
extends Resource

## Editor-authored capacity contract for ArcadeFxDirector's bounded spark pool.
## Keep the quality budgets at or below pool_size; the director clamps edited
## values defensively so an experimental resource can never overrun the pool.

@export_group("Pool")
@export_range(1, 512, 1) var pool_size: int = 100

@export_group("Quality budgets")
@export_range(1, 512, 1) var low_capacity: int = 32
@export_range(1, 512, 1) var medium_capacity: int = 64
@export_range(1, 512, 1) var high_capacity: int = 100


func capacity_for_quality(quality: int) -> int:
	var requested := high_capacity
	if quality == 0:
		requested = low_capacity
	elif quality == 1:
		requested = medium_capacity
	return clampi(requested, 1, maxi(1, pool_size))
