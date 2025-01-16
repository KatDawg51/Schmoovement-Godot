class_name GameRoot extends Node

#Refrences
@export_category("Refrences")
@onready var world3D:Node3D = %World3D
@onready var gui:Control = %GUI
@export var player_scene:PackedScene
@onready var local_player:Player

func _init() -> void:
	globals.game = self

func _ready() -> void:
	#Spawn the local player
	local_player = player_scene.instantiate() as Player
	add_child(local_player)
