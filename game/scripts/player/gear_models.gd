class_name GearModels
extends RefCounted
## Low-poly models of the crew's gear, shared by the first-person view and
## the avatar the others see: the 1989 VHS camcorder and the flashlight.
## Built from primitives with pixel textures (placeholders with the final
## silhouette).

static var _mats := {}


static func material(key: String, tint := Color.WHITE) -> StandardMaterial3D:
	var cache := "%s@%s" % [key, tint.to_html()]
	if _mats.has(cache):
		return _mats[cache]
	var m := StandardMaterial3D.new()
	var tex := load("res://assets/textures/%s.png" % key) as Texture2D
	if tex:
		m.albedo_texture = tex
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(4, 4, 4)
	m.roughness = 0.8
	_mats[cache] = m
	return m


static func flat(color: Color, emission := 0.0) -> StandardMaterial3D:
	var cache := "flat@%s@%f" % [color.to_html(), emission]
	if _mats.has(cache):
		return _mats[cache]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_mats[cache] = m
	return m


## The camcorder, lens forward (-Z), viewfinder at the back-left. Its red
## tally light is the child named "Tally" (on while recording).
static func camcorder() -> Node3D:
	var root := Node3D.new()
	root.name = "CamcorderModel"
	var body := _box(Vector3(0.09, 0.11, 0.22), material("camcorder"))
	root.add_child(body)
	var lens := _cyl(0.035, 0.045, 0.09, flat(Color(0.08, 0.08, 0.09)))
	lens.rotation.x = PI / 2
	lens.position = Vector3(0.0, 0.01, -0.15)
	root.add_child(lens)
	var glass := _cyl(0.026, 0.026, 0.004, flat(Color(0.25, 0.3, 0.4), 0.3))
	glass.rotation.x = PI / 2
	glass.position = Vector3(0.0, 0.01, -0.196)
	root.add_child(glass)
	var finder := _cyl(0.018, 0.018, 0.08, flat(Color(0.1, 0.1, 0.1)))
	finder.rotation.x = PI / 2
	finder.position = Vector3(-0.055, 0.045, 0.06)
	root.add_child(finder)
	var handle := _box(Vector3(0.03, 0.02, 0.14), flat(Color(0.12, 0.12, 0.12)))
	handle.position = Vector3(0.0, 0.075, -0.01)
	root.add_child(handle)
	var strap := _box(Vector3(0.012, 0.07, 0.12), flat(Color(0.2, 0.15, 0.1)))
	strap.position = Vector3(0.052, -0.005, 0.0)
	root.add_child(strap)
	var tally := MeshInstance3D.new()
	tally.name = "Tally"
	var dot := SphereMesh.new()
	dot.radius = 0.008
	dot.height = 0.016
	dot.radial_segments = 6
	dot.rings = 3
	tally.mesh = dot
	tally.material_override = flat(Color(1.0, 0.1, 0.05), 4.0)
	tally.position = Vector3(0.03, 0.05, -0.1)
	tally.visible = false
	root.add_child(tally)
	return root


## The flashlight, beam forward (-Z): a black rubber grip with rings, a
## knurled tail cap, a chrome bezel and a dim lens (the light itself is a
## SpotLight3D; the lens only hints at it).
static func flashlight() -> Node3D:
	var root := Node3D.new()
	root.name = "FlashlightModel"
	var rubber := flat(Color(0.07, 0.07, 0.08))
	var tube := _cyl(0.016, 0.016, 0.13, rubber)
	tube.rotation.x = PI / 2
	root.add_child(tube)
	for z: float in [-0.02, 0.01, 0.04]:
		var ring := _cyl(0.0175, 0.0175, 0.008, flat(Color(0.13, 0.13, 0.14)))
		ring.rotation.x = PI / 2
		ring.position.z = z
		root.add_child(ring)
	var tail := _cyl(0.017, 0.017, 0.02, flat(Color(0.18, 0.18, 0.19)))
	tail.rotation.x = PI / 2
	tail.position.z = 0.074
	root.add_child(tail)
	var head := _cyl(0.018, 0.026, 0.045, rubber)  # rotated: the bottom faces forward
	head.rotation.x = PI / 2
	head.position.z = -0.085
	root.add_child(head)
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.55, 0.55, 0.58)
	chrome.metallic = 0.9
	chrome.roughness = 0.3
	var bezel := _cyl(0.027, 0.027, 0.008, chrome)
	bezel.rotation.x = PI / 2
	bezel.position.z = -0.11
	root.add_child(bezel)
	var lens := _cyl(0.022, 0.022, 0.002, flat(Color(1.0, 0.92, 0.75), 0.5))
	lens.name = "Lamp"
	lens.rotation.x = PI / 2
	lens.position.z = -0.115
	root.add_child(lens)
	return root


static func _box(size: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	return mi


static func _cyl(top: float, bottom: float, height: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = 8
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	return mi


## Every MeshInstance3D under `node` (to set layers / shadows in bulk).
static func meshes(node: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	if node is GeometryInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(meshes(child))
	return out
