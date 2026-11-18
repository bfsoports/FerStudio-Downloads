extends SceneTree
## Offline tool: builds SECTOR ABANDONADO and bakes its navigation mesh from
## static colliders, saving it so the game never bakes on the phone.
## Run: godot --headless --path . -s tools/bake_navmesh.gd
## (classes are loaded dynamically: SceneTree tool scripts must not hard-reference
## project classes at parse time.)

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var map_script = load("res://scripts/map/sector_map.gd")
	var map = map_script.new()
	get_root().add_child(map)
	await process_frame
	map.build(false)
	await process_frame
	var nm: NavigationMesh = map_script.make_navmesh()
	map.nav_region.navigation_mesh = nm
	map.nav_region.bake_navigation_mesh(false)
	var polys := nm.get_polygon_count()
	var err := ResourceSaver.save(nm, map_script.NAVMESH_PATH, ResourceSaver.FLAG_COMPRESS)
	print("NAVMESH baked: %d polygons, %d vertices, saved=%s in %d ms" % [polys, nm.get_vertices().size(), error_string(err), Time.get_ticks_msec() - t0])
	print("spawn points: %d, doors: %d, barricades: %d" % [map.spawn_points.size(), map.doors.size(), map.barricades.size()])
	quit()
