class_name GameRoot extends Node

#Refrences
@export_category("Refrences")
@onready var world3D:Node3D = %World3D
@onready var gui:Control = %GUI
@onready var plr := preload("res://Player/Player.tscn").instantiate() as Player


func _init() -> void:
	globals.game = self

func _ready() -> void:
	#Spawn the local player
	add_child(plr)
