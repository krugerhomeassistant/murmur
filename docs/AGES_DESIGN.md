# Ages design

Towns advance through ages. An age decides which buildings and units a town may use and which services its people expect. Status: A1 (framework) built; later phases below.

## Ages
Twelve ages in four eras of three (2026-10-19, owner: "3 feels very little, 10 to 15 ages"): Stone, Bronze, Classical (Ancient era); Dark, Medieval, Renaissance (Medieval era); Industrial, Electric, Atomic (Industrial era); Information, Digital, Future (Modern era). The era (`Ages.tier`) decides the look (roads, houses, vehicles, clothes, sprite folders); the age decides what a town may build and train (`Ages.BUILDING`/`UNIT` give the era, `SPREAD`/`UNIT_SPREAD` the later age inside it), which research it has picked and how much knowledge it needs (`KNOW`, `PEAK`, `COINS` have twelve entries; each era's first age keeps the old four-age thresholds). Anything a service need depends on opens with its era so an age that starts expecting it can always build it. Saves from before carry no `av` key: their four ages become the first age of each era and their research choices move to the matching ages. Data lives in `client/scripts/ages.gd`: `BUILDING` and `UNIT` give the age of each building and unit (unlisted buildings are Ancient), `KNOW`, `PEAK` and `COINS` give what a town needs to enter each age.

## Advancing
A town gains knowledge every second: `pop / 50 * 0.5 * (1 + education coverage + 0.6 * culture coverage)`. It enters the next age when knowledge, peak population and treasury all reach the age's thresholds and its mood is at least 0.35 (`Ages.ready`). It also needs materials in stock (owner, 2026-10-19: advancing must be hard): planks, tools and metal, bought and kept back once the town is 70% of the way on knowledge. Nothing is on a timer: a bigger, better schooled, richer, happier town advances sooner.

## Expectations and the grace period
Some needs only exist from an age on (`Ages.EXPECTS`: fire, police and education from Medieval; power, water, sewage, waste, transit and health from Industrial). Before that age the need counts as fully met. In the age that opens it, the forgiveness fades by 25% every 400 s (`GRACE_STEP`), so people notice the missing service gradually. The clock holds while mood is under 0.35, so a struggling town is not hit with more demands. The planner treats such a need as at least half unmet during the grace period and builds ahead.

## Starting age
The setup screen has a "Starting age" option. The default is Ancient (since A2); Modern opens everything, the classic start. Existing saves keep their age. Console and sandbox: command `set_age`.

## Measured (Ancient start, planner towns, 6 runs of 4200 s)
All six towns survive and keep growing (pop 240 to 700). Before the planner and grace fixes, an Ancient start collapsed at the Industrial or Modern transition in most runs (pop 300 to 60), through three causes found in diagnosis: the grace floor hid the need from the planner, the floor vanished at once when the age changed, and the planner spent the treasury on upkeep it could not carry.

## Phases
- A1 (this change): framework, gating, expectations, setup option, tests (`tests/ages.gd`).
- A2: early-age content, then make Ancient the default start. Done: spearmen (Ancient unit trained at barracks, now an Ancient building; `tests/spear.gd`). Wells done (Ancient water source, 6 units, `tests/power.gd`). Ancient default start done. Left: galleys (huts dropped: the cottage zone already covers early housing).
- A3 (done, `research.gd`): research is a skill tree (docs/TREE_DESIGN.md): 36 nodes in six branches, bought with research points, applied through the policy modifier system (`City._collect_mods`), chosen by planner towns by temper (`Research.auto`), by humans in the Policies tab (`node` command). Scenario setup, god powers, globe view and the real-world map are planned in `docs/SANDBOX_DESIGN.md` (G1 to G5).
