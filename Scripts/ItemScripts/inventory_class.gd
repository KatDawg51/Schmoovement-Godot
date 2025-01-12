class_name Inventory extends Node3D

#Current_Gun
@export var current_item:PackedScene:
	set(new_item):
		for child in get_children():
			child.reparent(get_tree().root, true)
		current_item = new_item
		add_child(current_item.instantiate())
