# Town skill tree and physical links (design, owner requests 2026-10-19)

Owner's words: "a skill tree for each town, and they pick in which direction they go, and this tree should branch all the unlocks and
upgrades etc. Allowing players to focus on specific things but not be limited to their choices. I want the game to feel like a journey through
the ages." And: "I also dont want this connection stuff anymore, I want it to be physical connections with roads/railways built by the towns,
the towns shouldnt be limited in their space, their only limitation should be their resources and choices made."

Status: design only. Nothing here is built yet. It replaces the one-choice-per-age research list (`Research.TECHS`) and the territory rectangle.

## 1. The town skill tree

- Every town has its own tree, a graph of nodes in branches (a hub in the middle, six arms): Economy and trade, Industry and materials, Knowledge and
  culture, Governance and society, Military, Infrastructure and transport. Nodes connect to their neighbours; a node can be taken once a connected
  node is taken (and its age requirement is met), so a town chooses a direction but can reach everything given time, resources and choices.
- A node unlocks things: a building or unit, an upgrade tier for a whole kind of building, a policy, or a modifier (the existing `City.mods`
  system carries the numbers). Taking a node costs knowledge points (earned per second, as now, from people, schooling and culture) plus
  materials and coins, so it stays hard (see "Hard ages" in PLAN.md).
- The age becomes the journey: a town's age is derived from how deep it has gone (nodes taken per era band), not a separate gate with its own thresholds.
  The tree is drawn as a full-screen view like the reference image: taken nodes lit, reachable nodes outlined, the rest dim; hover shows cost and what it opens.
- Planner towns choose by temper: each town gets branch weights (a peaceful trader, a warlike miner...), so towns differ and the world has stories.
- Replaces: the 12 research pairs (their effects become nodes), `Ages.BUILDING`/`UNIT` gating (each building or unit is unlocked by a node), setup "Starting age" (starts the tree pre-filled to a depth).
- Saves: the node set per town; the old `tech` array and `age` map onto taken nodes. Tests: `tests/tree.gd`; `ageplay` must still end with living towns.

Slices: T1 data model and an auto-chosen tree producing the same unlocks as today (no UI); T2 the full-screen tree UI and manual picks; T3 planner weights and
temper; T4 remove the age gate and research pairs. Per-building upgrades (H2 to H4) hang off nodes: a node unlocks the next building tier.

## 2. Physical links, no territory limit

- Today a town owns a rectangle (`City.terr`, 48x32 growing by annexing) and "linked" means a flag on the shared network. Both go.
- Towns grow wherever they build: land belongs to a town by what it has built and zoned (a claim radius around its buildings and roads), contested at borders.
  The only limits are resources, coins and the choices made (and other towns' claims, rivers, terrain).
- Towns connect by real roads and railways laid on the map by the towns themselves, tile by tile, paid in materials and workers like any construction.
  Trade, travel, armies and shared supply move only along built links with capacity (road, rail; ports for sea), and a cut link cuts the flow.
  This is the same system as the hauling work (E4b-2): carts, trucks and trains with drivers on those links.
- The map is the endless procedural world already planned (EMPIRE_DESIGN.md); a founded town is just a new claim. No "linked" flag: a link exists if a path of built road or rail joins the two towns.

Slices: L1 claim-by-building replaces the rectangle (annex becomes claim growth); L2 links as built road/rail between towns, trade and supply follow them;
L3 vehicles with drivers on links (with E4b-2); L4 remove the linked flag and the shared-network shortcut. Tests: `tests/links.gd`, `tests/claim.gd`.

Order of work: finish H2 to H4 (building upgrades) first, since T1 builds on them; then L1, T1, L2, T2.
