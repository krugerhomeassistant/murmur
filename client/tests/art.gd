extends SceneTree
## Art: every building draws without a script error (a typo in art.gd would otherwise only show on screen).

const SHAPES := ["house", "terrace", "tower", "condo", "shop", "factory", "office", "farm", "orchard", "ranch", "green", "fishfarm"]


class Canvas extends Node2D:
	var drawn := 0

	func _draw() -> void:
		for age in 4:
			for shape in SHAPES:
				for lv in [1, 2, 3]:
					for night in [false, true]:
						if Art.building(self, Rect2(0, 0, 32, 32), shape, Color("c9b98a"), lv, true, night, 7 + lv, age):
							drawn += 1
		for id in Catalog.DEFS:
			if Art._has(id) and Art.service(self, Rect2(0, 0, 32, 32), id, true, false):
				drawn += 1


func _init() -> void:
	var c := Canvas.new()
	root.add_child(c)
	await process_frame
	await process_frame
	var ok: bool = c.drawn >= 4 * SHAPES.size() * 6 + 50
	print("ART_OK drawn=%d" % c.drawn if ok else "ART_FAIL drawn=%d" % c.drawn)
	quit(0 if ok else 1)
