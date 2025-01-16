class_name GameRoot extends Node

#Refrences
@export_category("Refrences")
@export var world3D:Node3D
@export var gui:Control
@export var player_scene:PackedScene
@onready var local_player:Player

func _init() -> void:
	globals.game = self

func _ready() -> void:
	#Spawn the local player
	local_player = player_scene.instantiate() as Player
	add_child(local_player)


func new_gui(scene:PackedScene):
	for child in gui.get_children():
		child.queue_free()
	add_child(scene.instantiate())
