class_name Market
extends RefCounted
## The shared goods exchange (docs/wiki/market.md). Every town reports what it offers (`sup`) and needs (`dem`) each sim
## second; prices follow the demand/supply ratio, so goods that nobody makes get dear and gluts get cheap.
## An "outside world" (`WORLD` units/s per reporting town) both offers and wants every good, which keeps prices bounded.
## Pure data, no scene: tests and mirrors use it directly.

const GOODS := ["crops", "food", "goods", "ore", "metal", "arms", "wood", "tools", "planks"]
const BASE := {"crops": 0.6, "food": 1.5, "goods": 2.0, "ore": 0.8, "metal": 3.0, "arms": 4.0, "wood": 0.7, "tools": 3.5, "planks": 1.4}
const LOW := 0.35  # price floor and ceiling as multiples of the base price
const HIGH := 3.0
const WORLD := 1.5  # outside-world offer and demand, units per second per reporting town
const ELASTIC := 0.6  # on top of that the outside world sells this share of any shortfall, at a rising price
const SENS := 0.6  # price = base * (demand / supply) ^ SENS
const IMPORT := 1.2  ## shortages not covered by a neighbour are bought abroad at this multiple of the world price
const FOLLOW := 0.12  # how fast the price chases its target, per second
const HIST := 90  # price samples kept (one per HIST_EVERY seconds)
const HIST_EVERY := 10.0
const CANDLE := 10  # samples (sim seconds) per candle
const CANDLES := 360  # candles kept (one hour of sim time)
const TAPE := 40  # trade tape entries kept

var price := BASE.duplicate()
var sup := {}  # units offered this window (by the towns)
var dem := {}  # units wanted this window
var last_sup := {}  # previous full window, for display and the purchase pool
var last_dem := {}
var pool := {}  # units a town may still buy as production input this second
var hist := {}  # good -> Array of prices
var reporters := 0  # towns that reported this window
var last_reporters := 0
var t := 0.0
var th := 0.0
var shock := {}  # good -> price multiplier from events, fading back to 1
var candles := {}  # good -> Array of [open, high, low, close, volume, offered/s, wanted/s], oldest first
var tape: Array = []  # newest first: {"t": sim seconds, "s": text}
var clock := 0.0  # sim seconds this market has run
var _cur := {}  # good -> candle being built (slot 7 counts samples), empty between candles
var _flow := {}  # "from|to|good" -> [units, coins] moved between towns since the last candle


func _init() -> void:
	for k in GOODS:
		sup[k] = 0.0
		dem[k] = 0.0
		last_sup[k] = 0.0
		last_dem[k] = 0.0
		pool[k] = 0.0
		hist[k] = [BASE[k]]
		candles[k] = []
		_cur[k] = []


## A town reports one second of trade. Call once per town per sim second.
func report(offered: Dictionary, wanted: Dictionary) -> void:
	reporters += 1
	for k in GOODS:
		sup[k] += float(offered.get(k, 0.0))
		dem[k] += float(wanted.get(k, 0.0))


## An event pushes prices: `mults` maps good -> multiplier (it fades over a few minutes).
func shock_by(mults: Dictionary) -> void:
	for k in mults:
		if k in GOODS:
			shock[k] = clampf(float(shock.get(k, 1.0)) * float(mults[k]), 0.5, 2.5)
	var parts: Array[String] = []
	for k in mults:
		if k in GOODS and absf(float(mults[k]) - 1.0) >= 0.01:
			parts.append("%s %+d%%" % [k, roundi((float(mults[k]) - 1.0) * 100.0)])
	if not parts.is_empty():
		note("Event: " + ", ".join(parts))


## One line on the trade tape (newest first).
func note(text: String) -> void:
	tape.push_front({"t": clock, "s": text})
	if tape.size() > TAPE:
		tape.pop_back()


## A town-to-town sale; the tape shows the total per route when a candle closes.
func flow_note(from: String, to: String, k: String, q: float, coins: float) -> void:
	var key := "%s|%s|%s" % [from, to, k]
	var f: Array = _flow.get(key, [0.0, 0.0])
	_flow[key] = [float(f[0]) + q, float(f[1]) + coins]


## Production inputs (crops for a mill, ore for a foundry, metal for a factory) can only be bought from what is on offer.
func take(k: String, want: float) -> float:
	var got := clampf(want, 0.0, float(pool[k]))
	pool[k] = float(pool[k]) - got
	return got


func ratio(k: String) -> float:
	return float(price[k]) / float(BASE[k])


## Advance time; `mult` scales every base price (the world market signal).
func tick(dt: float, mult := 1.0) -> void:
	t += dt
	th += dt
	if t < 1.0:
		return
	clock += t
	var w := WORLD * maxf(float(reporters), 1.0)
	for k in GOODS:
		var s: float = float(sup[k]) / t
		var d: float = float(dem[k]) / t
		last_sup[k] = s
		last_dem[k] = d
		var sh: float = float(shock.get(k, 1.0))
		shock[k] = move_toward(sh, 1.0, 0.004 * t)
		var target: float = float(BASE[k]) * mult * sh * clampf(pow((d + w) / (s + w + ELASTIC * maxf(d - s, 0.0)), SENS), LOW, HIGH)
		price[k] = float(price[k]) + (target - float(price[k])) * minf(FOLLOW * t, 1.0)
		pool[k] = s + w
		_sample(k, float(price[k]), s, d, minf(s, d) * t)
		sup[k] = 0.0
		dem[k] = 0.0
	last_reporters = reporters
	reporters = 0
	t = 0.0
	if th >= HIST_EVERY:
		th = 0.0
		var keys: Array = _flow.keys()
		keys.sort()
		for key: String in keys:
			var p := key.split("|")
			var f: Array = _flow[key]
			note("%s to %s: %.1f %s at $%.2f" % [p[0], p[1], float(f[0]), p[2], float(f[1]) / maxf(float(f[0]), 0.001)])
		_flow.clear()


## Full state for saves.
func to_dict() -> Dictionary:
	return {"price": price.duplicate(), "hist": hist.duplicate(true), "ls": last_sup.duplicate(), "ld": last_dem.duplicate(), "cd": candles.duplicate(true), "clock": clock}


func from_dict(d: Dictionary) -> void:
	for k in GOODS:
		var p: float = float((d.get("price", {}) as Dictionary).get(k, BASE[k]))
		price[k] = clampf(p, float(BASE[k]) * LOW, float(BASE[k]) * HIGH * 1.5)  # snapshots come from a possibly hostile host
		last_sup[k] = maxf(0.0, float((d.get("ls", {}) as Dictionary).get(k, 0.0)))
		last_dem[k] = maxf(0.0, float((d.get("ld", {}) as Dictionary).get(k, 0.0)))
		var h: Variant = (d.get("hist", {}) as Dictionary).get(k, [])
		if h is Array and not (h as Array).is_empty():
			hist[k] = (h as Array).slice(-HIST).map(func(x: Variant) -> float: return float(x))
		var cd: Variant = (d.get("cd", {}) as Dictionary).get(k, [])
		if cd is Array:
			var out: Array = []
			for c: Variant in (cd as Array).slice(-CANDLES):
				if c is Array and (c as Array).size() == 7:
					out.append((c as Array).map(func(x: Variant) -> float: return maxf(0.0, float(x))))
			if not out.is_empty():
				candles[k] = out
	clock = maxf(0.0, float(d.get("clock", clock)))


## What snapshots carry to clients (no history: the client records its own).
func brief() -> Dictionary:
	return {"price": price.duplicate(), "ls": last_sup.duplicate(), "ld": last_dem.duplicate()}


## Client side: take the host's prices and record them into the local candles (one sample per snapshot, about one a second).
func apply_brief(d: Dictionary) -> void:
	var keep := hist
	var kc := candles
	from_dict(d)
	hist = keep
	candles = kc
	clock += 1.0
	for k in GOODS:
		_sample(k, float(price[k]), float(last_sup[k]), float(last_dem[k]), minf(float(last_sup[k]), float(last_dem[k])))


## Fold one second into the candle being built; a finished candle is stored and the 15-minute line follows its close.
func _sample(k: String, p: float, s: float, d: float, vol: float) -> void:
	var c: Array = _cur[k]
	if c.is_empty():
		c = [p, p, p, p, 0.0, 0.0, 0.0, 0]
	c[1] = maxf(float(c[1]), p)
	c[2] = minf(float(c[2]), p)
	c[3] = p
	c[4] = float(c[4]) + vol
	c[5] = float(c[5]) + s
	c[6] = float(c[6]) + d
	c[7] = int(c[7]) + 1
	_cur[k] = c
	if int(c[7]) < CANDLE:
		return
	var n := float(c[7])
	var arr: Array = candles[k]
	arr.append([c[0], c[1], c[2], c[3], c[4], float(c[5]) / n, float(c[6]) / n])
	if arr.size() > CANDLES:
		arr.pop_front()
	_cur[k] = []
	(hist[k] as Array).append(p)
	if (hist[k] as Array).size() > HIST:
		(hist[k] as Array).pop_front()


## Candles merged `n` at a time, ending at the newest (to zoom a chart out). Volume adds up; offered and wanted average.
func merged(k: String, n: int) -> Array:
	var src: Array = candles[k]
	if n <= 1:
		return src.duplicate()
	var out: Array = []
	var i := src.size() % n
	while i + n <= src.size():
		var hi := -INF
		var lo := INF
		var vol := 0.0
		var s := 0.0
		var d := 0.0
		for j in range(i, i + n):
			var c: Array = src[j]
			hi = maxf(hi, float(c[1]))
			lo = minf(lo, float(c[2]))
			vol += float(c[4])
			s += float(c[5])
			d += float(c[6])
		out.append([(src[i] as Array)[0], hi, lo, (src[i + n - 1] as Array)[3], vol, s / n, d / n])
		i += n
	return out


## Moving average of candle closes, one value per candle (early values average what exists).
static func sma(cs: Array, period: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var sum := 0.0
	for i in cs.size():
		sum += float((cs[i] as Array)[3])
		if i >= period:
			sum -= float((cs[i - period] as Array)[3])
		out.append(sum / minf(float(i + 1), float(period)))
	return out


## High, low, average close, change (first open to last close), volatility (std dev of close-to-close change) and units cleared.
static func stats(cs: Array) -> Dictionary:
	if cs.is_empty():
		return {"hi": 0.0, "lo": 0.0, "avg": 0.0, "chg": 0.0, "vol": 0.0, "units": 0.0}
	var hi := -INF
	var lo := INF
	var sum := 0.0
	var units := 0.0
	for c: Array in cs:
		hi = maxf(hi, float(c[1]))
		lo = minf(lo, float(c[2]))
		sum += float(c[3])
		units += float(c[4])
	var rets: Array[float] = []
	for i in range(1, cs.size()):
		var a := float((cs[i - 1] as Array)[3])
		rets.append((float((cs[i] as Array)[3]) - a) / maxf(a, 0.001))
	var mean := 0.0
	for r in rets:
		mean += r
	mean /= maxf(float(rets.size()), 1.0)
	var v := 0.0
	for r in rets:
		v += (r - mean) * (r - mean)
	var o := float((cs[0] as Array)[0])
	return {"hi": hi, "lo": lo, "avg": sum / cs.size(), "chg": (float((cs[cs.size() - 1] as Array)[3]) - o) / maxf(o, 0.001), "vol": sqrt(v / maxf(float(rets.size()), 1.0)), "units": units}


## "shortage", "glut" or "balanced" from the last window's offers and wants.
func status(k: String) -> String:
	var s := float(last_sup[k])
	var d := float(last_dem[k])
	if d > s * 1.25 + 0.2:
		return "shortage"
	if s > d * 1.25 + 0.2:
		return "glut"
	return "balanced"


# ---------- trade between linked towns ----------

const FREIGHT := 0.06  ## per unit and per plot of distance, as a share of the base price
const SEA_FREIGHT := 0.7  ## freight share left when both towns have a port
const SEA_LINK := 0.8  ## link strength of a sea route between neighbours without a road
const RAIL_FREIGHT := 0.4  ## freight share left when both towns have a rail yard
const LINK_CAP := 2.0  ## units per second one pair of linked towns can move, before the treaty multiplier
const MIN_GAIN := 0.05  ## a trade must beat freight by this share of the base price


## Once per sim second: goods flow from towns where they are cheap to linked towns where they are dear, if the gap pays for freight.
## Needs a road link (Diplo.tmult is 0 for embargo, war and unlinked borders). Money changes hands; the freight is lost.
static func link_trade(towns: Array) -> void:
	if towns.size() < 2:
		return
	for k in GOODS:
		var sellers: Array = []
		var buyers: Array = []
		for t in towns:
			var o: float = t.trade_offer(k)
			var w: float = t.trade_want(k)
			if o > 0.05:
				sellers.append(t)
			if w > 0.05:
				buyers.append(t)
		if sellers.is_empty() or buyers.is_empty():
			continue
		sellers.sort_custom(func(a: City, b: City) -> bool: return float(a.price_loc[k]) < float(b.price_loc[k]))
		buyers.sort_custom(func(a: City, b: City) -> bool: return float(a.price_loc[k]) > float(b.price_loc[k]))
		for s: City in sellers:
			for b: City in buyers:
				var link: float = Diplo.tmult(s, b)
				var sea: bool = s.has_port() and b.has_port() and s != b and Diplo.side(s, b) >= 0
				if link <= 0.0 and sea and Diplo.treaty(s, b) != "embargo" and Diplo.treaty(s, b) != "war":
					link = SEA_LINK  # no road needed between neighbouring towns that both have a port
				if link <= 0.0 or s == b:
					continue
				var dist := maxi(absi(s.gpos.x - b.gpos.x), absi(s.gpos.y - b.gpos.y))
				var rail: bool = s.has_rail() and b.has_rail()  # both ends have a rail yard
				var freight: float = float(BASE[k]) * FREIGHT * dist * (RAIL_FREIGHT if rail else (SEA_FREIGHT if sea else 1.0))
				var gap: float = float(b.price_loc[k]) - float(s.price_loc[k]) - freight
				if gap < float(BASE[k]) * MIN_GAIN:
					continue
				var q: float = minf(minf(s.trade_offer(k), b.trade_want(k)), LINK_CAP * link * (2.0 if rail else 1.0))
				if q <= 0.0:
					continue
				var tp: float = float(s.price_loc[k]) + gap * 0.5  # the gain from trade is split
				s.stock[k] = float(s.stock[k]) - q
				b.stock[k] = float(b.stock[k]) + q
				s.coins += q * tp * City.RATE
				b.coins -= q * (tp + freight) * City.RATE
				s.sig.mk.flow_note(s.town_name, b.town_name, k, q, q * tp)
				s.traded[k] = float(s.traded.get(k, 0.0)) - q
				b.traded[k] = float(b.traded.get(k, 0.0)) + q
