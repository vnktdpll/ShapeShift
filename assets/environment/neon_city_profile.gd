class_name NeonCityProfile
extends Resource

## Editor-facing authoring profile for the pooled neon environment. Values are
## deliberately structural: artists can reshape a city tier or its window rhythm
## without expanding every repeated pane into an individual scene node.

@export_group("Close City")
@export_range(3, 8, 1) var close_chunk_count: int = 5
@export_range(10.0, 24.0, 0.5) var close_chunk_spacing: float = 14.5
@export_range(8.0, 28.0, 0.5) var close_front_z: float = 16.0
@export_range(0.1, 1.0, 0.01) var close_scroll_multiplier: float = 0.86
@export_range(6.0, 12.0, 0.1) var close_inner_edge: float = 7.8

@export_group("Mid City")
@export_range(3, 10, 1) var mid_chunk_count: int = 7
@export_range(10.0, 26.0, 0.5) var mid_chunk_spacing: float = 15.0
@export_range(8.0, 32.0, 0.5) var mid_front_z: float = 18.0
@export_range(0.1, 1.0, 0.01) var mid_scroll_multiplier: float = 0.52
@export_range(10.0, 24.0, 0.1) var mid_inner_edge: float = 13.0
@export_range(3.0, 7.0, 0.1) var mid_tier_pitch: float = 4.4
@export_range(3.0, 7.0, 0.1) var mid_tier_depth_pitch: float = 4.4

@export_group("Far City")
@export_range(3, 12, 1) var far_chunk_count: int = 8
@export_range(12.0, 30.0, 0.5) var far_chunk_spacing: float = 18.0
@export_range(10.0, 36.0, 0.5) var far_front_z: float = 20.0
@export_range(0.05, 1.0, 0.01) var far_scroll_multiplier: float = 0.30
@export_range(16.0, 34.0, 0.1) var far_inner_edge: float = 21.8
@export_range(3.0, 8.0, 0.1) var far_tier_pitch: float = 4.8
@export_range(3.0, 8.0, 0.1) var far_tier_depth_pitch: float = 4.8

@export_group("Window Modules")
@export_range(3, 8, 1) var close_window_rows: int = 6
@export_range(2, 5, 1) var close_window_columns: int = 3
@export_range(0.25, 0.8, 0.01) var close_window_height: float = 0.42
@export_range(0.1, 0.4, 0.01) var close_window_width_ratio: float = 0.17
@export_range(2, 7, 1) var mid_window_rows: int = 4
@export_range(2, 4, 1) var mid_window_columns: int = 2
@export_range(0.25, 0.8, 0.01) var mid_window_height: float = 0.34
@export_range(0.1, 0.4, 0.01) var mid_window_width_ratio: float = 0.24
@export_range(3, 8, 1) var far_window_rows: int = 5
@export_range(2, 4, 1) var far_window_columns: int = 2
@export_range(0.25, 0.8, 0.01) var far_window_height: float = 0.30
@export_range(0.1, 0.4, 0.01) var far_window_width_ratio: float = 0.22
@export_range(0.0, 2.0, 0.01) var window_emission_strength: float = 0.50

@export_group("Bounded Effects")
@export_range(0, 8, 1) var real_light_count: int = 4
@export_range(8, 96, 1) var atmosphere_particle_count: int = 36
