class_name Item extends Node3D
#Variables
var equipped:bool
var stored:bool

func _process(_delta: float):
	if self and is_instance_valid(self):
		if get_parent() is Inventory:
			equipped = true
		else:
			equipped = false
