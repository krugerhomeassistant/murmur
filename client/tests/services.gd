extends SceneTree
## Service trade: a town short of coverage buys it from a road-linked neighbour that has plenty, paying that neighbour; unlinked or embargoed towns cannot.
func _init() -> void:
	var errs: Array[String] = []
	var sg := Signals.new()
	var a := City.new(sg)  # seller
	var b := City.new(sg)  # buyer
	a.town_name = "A"
	b.town_name = "B"
	a.gpos = Vector2i(0, 0)
	b.gpos = Vector2i(1, 0)
	a.partners.append(b)
	b.partners.append(a)
	for t in [a, b]:
		t.homes.assign([1, 2, 3, 4, 5, 6, 7, 8])
		t.pop = 100
		t.cov_own = {"health": 0.0, "police": 0.0, "fire": 0.0, "edu": 0.0, "leisure": 0.0}
		t.coins = 1000.0
	a.cov_own["health"] = 1.0
	b._svc_trade()
	if float(b.svc_in["health"]) != 0.0:
		errs.append("unlinked towns must not trade services")
	a.gate[1] = 1
	b.gate[3] = 1
	b._svc_trade()
	var got := float(b.svc_in["health"])
	var fee := float(b.svc_buy.get("A", 0.0))
	if got <= 0.0 or got > 0.36 or fee <= 0.0 or absf(float(b.cov["health"]) - got) > 0.001:
		errs.append("the buyer should get coverage from the seller (got %.2f fee %.3f)" % [got, fee])
	if float(b.svc_in["police"]) != 0.0:
		errs.append("a seller with no coverage has nothing to sell")
	b.coins = 0.0
	b._svc_trade()
	if float(b.svc_in["health"]) != 0.0:
		errs.append("a broke town cannot buy services")
	b.coins = 1000.0
	Diplo.sign_treaty(a, b, "embargo")
	b._svc_trade()
	if float(b.svc_in["health"]) != 0.0:
		errs.append("an embargo must stop service trade")
	print("SERVICES_OK" if errs.is_empty() else "SERVICES_FAIL " + str(errs))
	quit()
