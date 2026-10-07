class_name TileLayer
extends Node2D
## One 16x16-tile slice of the static map. Zoomed in it is baked into a texture (one quad per frame instead of
## thousands of draw commands); zoomed out it draws flat tiles directly. Main re-records it on a budget.

const SC := 2  # bake resolution: texels per world pixel, so zooming in stays sharp

var m: Node
var town: City
var x0 := 0
var y0 := 0
var x1 := 0
var y1 := 0
var stamp := 0
var vp: SubViewport
var cv: Bake
var spr: Sprite2D


class Bake:
	extends Node2D
	var t: TileLayer

	func _draw() -> void:
		t.m.draw_chunk(self, t.town, t.x0, t.y0, t.x1, t.y1)


func _bake_setup() -> void:
	var o := Vector2(x0, y0) * 32.0
	vp = SubViewport.new()
	vp.size = Vector2i((x1 - x0 + 1) * 32 * SC, (y1 - y0 + 1) * 32 * SC)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	cv = Bake.new()
	cv.t = self
	cv.scale = Vector2(SC, SC)
	cv.position = -o * SC
	vp.add_child(cv)
	spr = Sprite2D.new()
	spr.centered = false
	spr.position = o
	spr.scale = Vector2(1.0 / SC, 1.0 / SC)
	spr.texture = vp.get_texture()
	spr.visible = false
	add_child(spr)


## lod 0 = bake to texture; otherwise draw directly.
func refresh(lod: int) -> void:
	if lod == 0 and vp == null:  # allocate the texture only when this chunk is first seen zoomed in
		_bake_setup()
	if spr != null:
		spr.visible = lod == 0
	if lod == 0:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		cv.queue_redraw()
	queue_redraw()


func _draw() -> void:
	if m.far_mode != 0:
		m.draw_chunk(self, town, x0, y0, x1, y1)
