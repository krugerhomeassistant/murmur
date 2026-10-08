class_name Market
extends RefCounted
## The shared goods exchange (docs/wiki/market.md). Every town reports what it offers (`sup`) and needs (`dem`) each sim
## second; prices follow the demand/supply ratio, so goods that nobody makes get dear and gluts get cheap.
## An "outside world" (`WORLD` units/s per reporting town) both offers and wants every good, which keeps prices bounded.
## Pure data, no scene: tests and mirrors use it directly.

const GOODS := ["crops", "food", "goods", "ore", "metal"]
const BASE := {"crops": 0.6, "food": 1.5, "goods": 2.0, "ore": 0.8, "metal": 3.0}
const LOW := 0.35  # price floor and ceiling as multiples of the base price
const HIGH := 3.0
const WORLD := 1.5  # outside-world offer and demand, units per second per reporting town
const ELASTIC := 0.6  # on top of that the outside world sells this share of any shortfall, at a rising price
const SENS := 0.6  # price = base * (demand / supply) ^ SENS
const IMPORT := 1.2  ## shortages not covered by a neighbour are bought abroad at this multiple of the world price
const FOLLOW := 0.12  # how fast the price chases its target, per second
const HIST := 90  # price samples kept (one per HIST_EVERY seconds)
const HIST_EVERY := 10.0

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
var _rec := 0
var shock := {}  # good -> price multiplier from events, fading back to 1


func _init() -> void:
	for k in GOODS:
		sup[k] = 0.0
		dem[k] = 0.0
		last_sup[k] = 0.0
		last_dem[k] = 0.0
		pool[k] = 0.0
		hist[k] = [BASE[k]]


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
		sup[k] = 0.0
		dem[k] = 0.0
	last_reporters = reporters
	reporters = 0
	t = 0.0
	if th >= HIST_EVERY:
		th = 0.0
		for k in GOODS:
			(hist[k] as Array).append(price[k])
			if (hist[k] as Array).size() > HIST:
				(hist[k] as Array).pop_front()


## Full state for saves.
func to_dict() -> Dictionary:
	return {"price": price.duplicate(), "hist": hist.duplicate(true), "ls": last_sup.duplicate(), "ld": last_dem.duplicate()}


func from_dict(d: Dictionary) -> void:
	for k in GOODS:
		var p: float = float((d.get("price", {}) as Dictionary).get(k, BASE[k]))
		price[k] = clampf(p, float(BASE[k]) * LOW, float(BASE[k]) * HIGH * 1.5)  # snapshots come from a possibly hostile host
		last_sup[k] = maxf(0.0, float((d.get("ls", {}) as Dictionary).get(k, 0.0)))
		last_dem[k] = maxf(0.0, float((d.get("ld", {}) as Dictionary).get(k, 0.0)))
		var h: Variant = (d.get("hist", {}) as Dictionary).get(k, [])
		if h is Array and not (h as Array).is_empty():
			hist[k] = (h as Array).slice(-HIST).map(func(x: Variant) -> float: return float(x))


## What snapshots carry to clients (no history: the client records its own).
func brief() -> Dictionary:
	return {"price": price.duplicate(), "ls": last_sup.duplicate(), "ld": last_dem.duplicate()}


## Client side: take the host's prices and keep a local history (one sample per HIST_EVERY real seconds).
func apply_brief(d: Dictionary) -> void:
	var keep := hist
	from_dict(d)
	hist = keep
	var now := Time.get_ticks_msec()
	if now - _rec >= int(HIST_EVERY * 1000.0):
		_rec = now
		for k in GOODS:
			(hist[k] as Array).append(price[k])
			if (hist[k] as Array).size() > HIST:
				(hist[k] as Array).pop_front()


# ---------- trade between linked towns ----------

const FREIGHT := 0.06  ## per unit and per plot of distance, as a share of the base price
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
				if link <= 0.0 or s == b:
					continue
				var dist := maxi(absi(s.gpos.x - b.gpos.x), absi(s.gpos.y - b.gpos.y))
				var freight: float = float(BASE[k]) * FREIGHT * dist
				var gap: float = float(b.price_loc[k]) - float(s.price_loc[k]) - freight
				if gap < float(BASE[k]) * MIN_GAIN:
					continue
				var q: float = minf(minf(s.trade_offer(k), b.trade_want(k)), LINK_CAP * link)
				if q <= 0.0:
					continue
				var tp: float = float(s.price_loc[k]) + gap * 0.5  # the gain from trade is split
				s.stock[k] = float(s.stock[k]) - q
				b.stock[k] = float(b.stock[k]) + q
				s.coins += q * tp * City.RATE
				b.coins -= q * (tp + freight) * City.RATE
				s.traded[k] = float(s.traded.get(k, 0.0)) - q
				b.traded[k] = float(b.traded.get(k, 0.0)) + q
