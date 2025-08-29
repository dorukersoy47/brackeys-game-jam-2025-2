class_name UpgradeDef
extends Resource
@export var id: StringName
@export var display_name: String
@export_multiline var desc: String
@export var icon: Texture2D
@export var base_cost: int = 100
@export var max_level: int = 5
@export var curve: StringName = &"linear"  # linear, steep, flat
@export var stat_key: StringName = &"hp"   # maps to Save.upgrades keys
@export var per_level_value: float = 1.0   # how much each level adds
