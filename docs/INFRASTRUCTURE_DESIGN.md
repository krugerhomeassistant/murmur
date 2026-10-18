# Infrastructure design (E5) and mechanics borrowed from OpenTTD

Status: planned. Nothing here is implemented yet. It follows the E4 economy work (upkeep and maintenance, household v2) in the order of work in [PLAN.md](PLAN.md).

## Scope

E5 adds rail, ports and power tiers on top of the goods market (`Market`, `City._trade`). The aim is that moving goods between towns costs something, so distance, route choice and maintenance matter, while the game stays a cozy builder rather than a logistics simulator.

## Inspiration: OpenTTD

[OpenTTD](https://www.openttd.org) is a transport simulation whose mechanics suit this work. We borrow ideas only.

**Licence rule.** OpenTTD's code is GPL v2. No OpenTTD code is copied, translated or adapted into Murmur, and nothing is derived from reading its source. Mechanics are reimplemented from the idea. Its graphics, sound and music packs are separate projects with their own licences; none is used. Anything third-party that ships in the repo needs its licence recorded before it is added.

### Adopted

| Idea | How it fits Murmur | Where |
|---|---|---|
| Cargo payment that falls with transit time and distance | A traded good's price at the destination is reduced by a time and distance factor, so slow or long routes pay less. Rail and ports differ by speed, capacity and range. | `Market.link_trade`, E5 rail and ports |
| Station catchment radius | A rail station, port or airport serves only buildings within a few tiles, instead of whole-network coverage. Placement then matters. | new station buildings |
| Vehicle servicing and breakdowns | Rolling stock and ships have upkeep and a wear value. Unserviced vehicles slow down or stop until repaired. Shares the upkeep and maintenance model from E4 slice 3. | E4 upkeep, E5 |
| Simplified signal blocking on rail | One train per rail segment, with simple automatic block rules. No manual signal placement. | rail, `Traffic` |
| Town growth driven by served stations | Compare with the D5 growth tuning: a town served by good transport grows faster. Only adopted if D5 measurements show a gap. | D5 |

### Optional, later

- Economy cycles and recessions. Risky for solvency, so only after upkeep is proven stable in long parallel runs.

### Not adopted

- The AI and script API.
- The NewGRF content system.
- OpenTTD's pathfinders (YAPF). Murmur uses its own road network and `Traffic`; rail gets a small purpose-built router.
- Full signal logic, timetables and orders. Too much for a cozy builder.

## Phases

1. **E5a Upkeep and wear model** (shared with E4 slice 3): per-building and per-road upkeep, wear that grows without maintenance, repair cost. Acceptance: 6 of 6 parallel long runs stay solvent.
2. **E5b Rail** (first slice done: the Rail yard, a building that cuts freight by 60% and doubles link capacity when both towns have one; `Market.link_trade`, `tests/rail.gd`). Catchment done (the yard's effect scales with the industry within 14 tiles). Still to do: track pieces, trains moving goods between linked towns, block rule, payment decay. Acceptance: a test where a train route beats a road route over distance, and one where a broken or unserviced train stops delivering.
3. **E5c Ports** (done in a first form: ports link neighbouring towns without a road and cut freight 30%; `Market.link_trade`, `tests/rail.gd`): harbour and ship routes with their own speed, capacity and range, using the same payment decay.
4. **E5d Power tiers** (power done: wind 8, solar 14, coal 40, hydro 55, gas 80, nuclear 200 units; `tests/power.gd`): fuel done: Refinery, Fuel good, coal and gas burn it, `tests/fuel.gd`; still to do, water tiers feeding the Ages needs (see [AGES_DESIGN.md](AGES_DESIGN.md)).

Every phase ships with a headless test wired into CI, a wiki page, and a CHANGELOG line. The performance pass stays the last step before a release.
