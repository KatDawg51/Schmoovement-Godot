extends Node
var ground_normal_ray
#UNUSED:
func get_slope() -> Vector3:
	var normal:Vector3
	if ground_normal_ray.is_colliding():
		normal = ground_normal_ray.get_collision_normal()
	if not normal.is_equal_approx(Vector3.UP):
		var tangent = normal.cross(Vector3.DOWN)
		var slope = normal.cross(tangent)
		return abs(slope.normalized())
	else:
		return Vector3.ZERO
