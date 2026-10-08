class_name NetWorld
extends RefCounted
## World state over the wire (docs/MULTIPLAYER.md, phase 3). The host sends each town's full `to_dict` snapshot, compressed
## (about 4 KB per town), and clients mirror it; measured, so no diffing yet. Pure functions, so tests need no scene.


static func pack(t: City) -> PackedByteArray:
	return var_to_bytes(t.to_dict()).compress(FileAccess.COMPRESSION_GZIP)


static func unpack(b: PackedByteArray) -> Dictionary:
	var d: Variant = bytes_to_var(b.decompress_dynamic(4 << 20, FileAccess.COMPRESSION_GZIP))  # size-capped: the sender is untrusted
	return d if d is Dictionary else {}


## Gives `peer` the first free town and makes it player-controlled; returns its index, or -1 when every town is taken.
static func assign(towns: Array[City], peer: int, prefer := -1) -> int:
	if prefer >= 0 and prefer < towns.size() and towns[prefer].owner == 0:  # a returning player gets their old town back
		towns[prefer].owner = peer
		towns[prefer].human = true
		return prefer
	for i in towns.size():
		if towns[i].owner == 0:
			towns[i].owner = peer
			towns[i].human = true
			return i
	return -1


## Hands a leaving player's town back to the planner.
static func release(towns: Array[City], peer: int) -> void:
	for t in towns:
		if t.owner == peer:
			t.owner = 0
			t.human = false


static func meta(towns: Array[City], mine: int) -> Dictionary:
	return {"n": towns.size(), "mine": mine}


## Client side: an empty mirror of `n` towns, all wired as neighbours. Real contents arrive as snapshots.
static func mirror(sig: Signals, n: int) -> Array[City]:
	var out: Array[City] = []
	for k in n:
		var t := City.new(sig)
		t.human = false
		for o in out:
			o.partners.append(t)
			t.partners.append(o)
		out.append(t)
	return out
