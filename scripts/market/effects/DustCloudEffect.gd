extends ColorRect
class_name DustCloudEffect

@onready var timer = $Timer

func _ready():
	# Set up the dust cloud overlay
	self_modulate.a = 0.2  # 20% opacity as specified
	timer.wait_time = 2.0  # 2 seconds duration
	timer.one_shot = true
	timer.start()

func _on_timer_timeout():
	queue_free()  # Remove the effect after duration
