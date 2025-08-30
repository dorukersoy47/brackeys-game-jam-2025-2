class_name ItemDef
extends Resource
enum Kind { ACTIVE, PASSIVE, CONSUMABLE }
@export var id: StringName
@export var display_name: String
@export_multiline var desc: String
@export var icon: Texture2D
@export var cost: int = 60
@export var kind: Kind = Kind.ACTIVE
@export var stackable: bool = true
@export var max_stack: int = 3
@export var rarity: StringName = &"common"  # optional rotation/balance
@export var effect_scene: PackedScene       # -> ItemEffect (see below)
@export var one_time_use: bool = false        # For consumables that are removed after use
