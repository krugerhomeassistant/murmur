extends SceneTree
## Growth baseline: seconds for one fresh town (planner on) to reach 100 and 300 people.
## Not in CI: run it 3 times before and after a growth change and compare. Only fails if the town never grows past 20.
## Baseline 2026-10-09 (3 runs, 4800 s cap): to100 = never / 826 s / 1682 s; pop at cap 64 / 106 / 110. One run reached 218 at 2400 s. Very noisy: the sim is not deterministic.
const LIMIT_SECS := 4800  # game seconds

func _init() -> void:
	var sig := Signals.new()
	var c := City.new(sig)
	c.seed_start()
	c.next_fire = 9999.0
	c.ev_t = 9999.0
	c.auto_mode = 2
	c.coins = 3000.0
	var t100 := -1.0
	var t300 := -1.0
	var t := 0.0
	while t < LIMIT_SECS:
		sig.tick(0.1)
		c.tick(0.1)
		t += 0.1
		if t100 < 0.0 and c.pop >= 100:
			t100 = t
		if t300 < 0.0 and c.pop >= 300:
			t300 = t
			break
	print("GROWTH to100=%.0fs to300=%.0fs pop=%d day=%d" % [t100, t300, c.pop, c.day])
	print("GROWTH_OK" if c.pop > 20 else "GROWTH_FAIL pop %d" % c.pop)
	quit()
