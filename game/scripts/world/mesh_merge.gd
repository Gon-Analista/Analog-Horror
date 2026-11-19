class_name MeshMerge
extends RefCounted
## Turns a model built from many primitive parts (boxes, cylinders) into a
## single MeshInstance3D with one surface per material. A part is a draw
## call in every pass (depth, colour, each shadow), so a battery of eleven
## boxes costs eleven times a single mesh; merged it costs one per
## material. With a cache key the merged mesh is shared by every copy of
## the model, and the renderer instances identical meshes together.

static var _cache := {}


## Merges the MeshInstance3D children of `root` (not those named in `keep`,
## nor those with children of their own) into one child named `name`.
## Returns it (null if there was nothing to merge).
static func merge_children(root: Node3D, keep: Array[String] = [], cache_key := "", name := "Body") -> MeshInstance3D:
	var parts: Array[MeshInstance3D] = []
	for child in root.get_children():
		var mi := child as MeshInstance3D
		if mi and mi.mesh and mi.get_child_count() == 0 and not keep.has(String(mi.name)):
			parts.append(mi)
	return merge(root, parts, cache_key, name)


## Merges `parts` (children of `root`) into one child of `root`.
static func merge(root: Node3D, parts: Array[MeshInstance3D], cache_key := "", name := "Body") -> MeshInstance3D:
	if parts.size() < 2:
		return null
	var mesh: ArrayMesh = _cache.get(cache_key) if cache_key != "" else null
	if mesh == null:
		mesh = _build(parts)
		if cache_key != "":
			_cache[cache_key] = mesh
	var out := MeshInstance3D.new()
	out.name = name
	out.mesh = mesh
	out.cast_shadow = parts[0].cast_shadow
	out.layers = parts[0].layers
	for mi in parts:
		root.remove_child(mi)
		mi.free()
	root.add_child(out)
	root.move_child(out, 0)
	return out


static func _build(parts: Array[MeshInstance3D]) -> ArrayMesh:
	var tools := {}  # Material -> SurfaceTool, in order of appearance
	for mi in parts:
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.material_override
			if m == null:
				m = mi.get_surface_override_material(s)
			if m == null:
				m = mi.mesh.surface_get_material(s)
			if not tools.has(m):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[m] = st
			(tools[m] as SurfaceTool).append_from(mi.mesh, s, mi.transform)
	var mesh := ArrayMesh.new()
	for m: Material in tools:
		(tools[m] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	return mesh
