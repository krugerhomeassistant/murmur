extends SceneTree
## Rejoin token is stable per install and long enough.
func _init() -> void:
	var a := NetPlay._my_token()
	var b := NetPlay._my_token()
	var ok := a == b and a.length() >= 16
	print("TOKEN_OK" if ok else "TOKEN_FAIL")
	quit()
