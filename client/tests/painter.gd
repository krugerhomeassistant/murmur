extends SceneTree
## Painter: baked sprites exist, have the right size, are cached, and are not blank.


func _init() -> void:
	var ok := true
	var t0 := Time.get_ticks_msec()
	for t in [Painter.car(Color("c0392b")), Painter.car(Color("c0392b"), true), Painter.cart(), Painter.person()]:
		var im: Image = t.get_image()
		var seen := 0
		for y in im.get_height():
			for x in im.get_width():
				if im.get_pixel(x, y).a > 0.5:
					seen += 1
		if seen < 30:
			ok = false
			print("blank sprite ", im.get_size())
	var a := Painter.car(Color("c0392b"))
	if a != Painter.car(Color("c0392b")) or Painter.car(Color("c0392b")).get_width() != 36:
		ok = false
		print("car cache or size wrong")
	print("painter bake ms: ", Time.get_ticks_msec() - t0)
	print("PAINTER_OK" if ok else "PAINTER_FAIL")
	quit()
