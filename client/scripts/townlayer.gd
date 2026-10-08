class_name TownLayer
extends Node2D
## One town in the world: its tile chunks, a live thumbnail for far zoom, and its overlay (fire, traffic, people).
## Sits at the town's grid offset, so every town is drawn in one continuous map.

var m: Node
var town: City
var chunks: Array[TileLayer] = []
var cr: Node2D  # parent of the chunks, hidden at far zoom
var spr_thumb: Sprite2D
var img: Image
var base: Image
var base_sig := 0
var rr := 0
var thumb_stamp := -100000


func build() -> void:
	cr = Node2D.new()
	cr.show_behind_parent = true
	add_child(cr)
	for cy in ceili(City.H / float(m.CH)):
		for cx in ceili(City.W / float(m.CH)):
			var l := TileLayer.new()
			l.m = m
			l.town = town
			l.x0 = cx * m.CH
			l.y0 = cy * m.CH
			l.x1 = mini(City.W, cx * m.CH + m.CH) - 1
			l.y1 = mini(City.H, cy * m.CH + m.CH) - 1
			l.show_behind_parent = true
			cr.add_child(l)
			chunks.append(l)
	spr_thumb = Sprite2D.new()
	spr_thumb.centered = false
	spr_thumb.scale = Vector2(m.TILE, m.TILE)
	spr_thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr_thumb.show_behind_parent = true
	spr_thumb.visible = false
	add_child(spr_thumb)


## Rebuild the one-pixel-per-tile picture shown when the whole world is in view.
func refresh_thumb() -> void:
	var t := town
	var sig := hash([t.terr, t.water, t.ground, t.season])
	if base == null or sig != base_sig:
		base_sig = sig
		base = Image.create(City.W, City.H, false, Image.FORMAT_RGBA8)
		var grass: Color = Civics.SEASONS[t.season]["grass"]
		base.fill(grass.darkened(0.35))
		base.fill_rect(t.terr, grass)
		var tint := {World.K.SAND: Color("d8c68c"), World.K.FOREST: grass.darkened(0.3), World.K.HILL: grass.lerp(Color("9a8a5a"), 0.5), World.K.ROCK: Color("808084")}
		for i in t.water.size():
			if t.water[i] == 1:
				base.set_pixel(i % City.W, i / City.W, Color("3f7fb8"))
			elif tint.has(int(t.ground[i])):
				base.set_pixel(i % City.W, i / City.W, tint[int(t.ground[i])])
	img = base.duplicate()
	for i in t.cells:
		var g: int = t.grid[i]
		if g != Catalog.Id.EMPTY:
			var c: Color = Catalog.DEFS[g]["col"]
			if Catalog.DEFS[g]["kind"] == "zone" and t.lvl[i] == 0:
				c = c.lerp(Color("8fae78"), 0.6)
			img.set_pixel(i % City.W, i / City.W, c)
	if spr_thumb.texture == null:
		spr_thumb.texture = ImageTexture.create_from_image(img)
	else:
		(spr_thumb.texture as ImageTexture).update(img)


func _draw() -> void:
	m.draw_overlay(self, town)
