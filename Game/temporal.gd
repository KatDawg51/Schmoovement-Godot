class_name Temporal extends Node

func edit(timer:SceneTreeTimer, time:float):
	timer = get_tree().create_timer(time) as SceneTreeTimer
	print(timer.time_left)


func spawn(timers:Array[SceneTreeTimer]):
	for timer in timers:
		timer = get_tree().create_timer(0) as SceneTreeTimer

func _init() -> void:
	globals.temporal = self
