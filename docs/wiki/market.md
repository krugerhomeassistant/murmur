# Market

Five goods are traded: crops, food, goods, ore and metal. Each good has its own price with its own base (crops 0.6, food 1.5, goods 2.0, ore 0.8, metal 3.0) and moves on its own supply and demand; the five never share a price. There are two levels: the **world price** of each good (the outside market, set by all towns together) and each town's **local price** (scarcity inside the town, between selling abroad at 80% and buying abroad at 120% of the world price). Linked towns also trade goods with each other when the price gap pays for freight. Implementation: `client/scripts/market.gd` (class `Market`), owned by `Signals` (`sig.mk`), used by `City._trade`. Test: `client/tests/market.gd`.

## Price formation
Every sim second `Market.tick` closes a window. For each good:

```
S = offered this window (units/s) + W        D = wanted this window (units/s) + W
W = WORLD * reporting towns                   WORLD = 1.5 (the outside world offers and wants this much per town)
target = BASE[good] * signal * clamp((D / S) ^ 0.6, 0.35, 3.0)
price += (target - price) * min(0.12 * window, 1)
```

`signal` is `1 + 0.3 * market` from `Signals` (the world market signal, -1..1). Base prices: crops 0.6, food 1.5, goods 2.0, ore 0.8, metal 3.0. The outside world keeps prices bounded and stops one idle town from moving a price alone. A good nobody trades stays at base.

The price is sampled into a history every 10 s (90 samples, 15 minutes) for the Market window. Clients of a multiplayer game receive prices and last-window supply and demand inside every town snapshot (`City.to_dict` key `mk`) and keep their own history.

## Local prices
`City._trade` sets `price_loc[good]` every second:

```
cover = (stock + 60 * production) / use                  (seconds of cover; use = need_rate)
local = world price * lerp(IMPORT 1.2, 0.8, clamp((cover - 10) / 190, 0, 1))
```
A town with plenty of a good (a mining town's ore, a farming town's food) pays near 80% of the world price; a town short of it pays up to 120%. A good the town neither uses nor stocks sits at 80% (export parity). Households pay the local food and goods prices, so inflation is local (see [Households](households.md)). `IMPORT` is also the price multiplier for basic needs bought abroad.

## Trade between linked towns
`Market.link_trade(towns)` runs once per sim second (`Main._process`, after `Diplo.second`). For each good, a town offers stock above `max(use * 90 s, 10% of storage)` and wants up to `use * 45 s` minus stock. Sellers are sorted cheap first, buyers dear first; a pair trades when both borders have a road (`Diplo.tmult > 0`; embargo and war block it) and

```
gap = buyer local price - seller local price - freight        freight = base * 0.06 * plot distance
trade if gap >= base * 0.05;  quantity <= min(offer, want, 2.0 * tmult) per second
seller price = seller local + gap / 2;   buyer pays seller price + freight (the freight is lost)
```
So a town sitting on ore sells it cheaply to a linked town with a foundry, and a blockade or embargo shows up as shortages. Trade only reaches adjacent plots today (multi-hop routes and ports are planned).

## What towns do with it
`City._trade` (once per sim second per town):

| Flow | Rule |
|---|---|
| Basic needs | A town needs `pop * 0.05` food and `pop * 0.03 + shop_jobs * 0.02` goods per second. Stock covers what it can; the shortfall is bought at the market price (`imp`) and counted as demand. Never limited, so a famine raises the price instead of stopping the town. |
| Sales | Stock above the export line (`cap * 0.8`, or `cap * 0.2` with a depot or port) is sold at `price * 0.8 * (1 + 0.25 * depots)` (a port counts as two depots). The sold fraction is scaled by `clamp(price / base, 0.4, 1.5)`: cheap goods are held back, dear goods are pushed out. |
| Input purchases | Idle mill capacity buys crops, idle foundry capacity buys ore, factories short of metal buy metal, when the treasury exceeds 120 coins and the purchase costs at most 5% of coins per second. Purchases come from the market's pool for that second (everyone's last-window offers plus the world's `W`); when the pool is empty the town simply cannot buy. |
| Reporting | The town reports its sales as supply and its shortfalls and wanted inputs as demand (`Market.report`). |

Because input purchases are limited to what is on offer, a mill in a town without farms only works as far as other towns (or the world) supply crops, and its demand pushes the crop price up, which makes farming elsewhere pay. The same holds for foundries (ore) and factories (metal).

## Market window
Windows > Market (`Hud._market_win`). Columns: price, change against base, units offered and wanted per second in the last window, a 15-minute price line (white line is the base price), and your town's stock, sales and purchases. The note line names goods worth selling (price over base by 25% and you produce them) and goods in glut (under 80% of base).

## Save and multiplayer
`Main.save_game` stores `sig.mk.to_dict()`; a new game starts with a fresh `Market`. `Market.from_dict` clamps prices, so a hostile snapshot cannot inject absurd values.

## Where in the code
| Topic | Code |
|---|---|
| Price formation, pool, history | `Market.tick`, `Market.take`, `Market.report` (`market.gd`) |
| Town trade, local prices | `City._trade`, `City.trade_offer`, `City.trade_want` (`city.gd`) |
| Trade between towns | `Market.link_trade` (`market.gd`) |
| Snapshot and save | `Market.brief`, `Market.apply_brief`, `Market.to_dict`, `City.to_dict`, `Main.save_game` |
| Window | `Hud._market_win`, `Hud._market_refresh`, `Hud._spark` |

## Open questions
- Link trade covers adjacent plots only; multi-hop routes, ports and shipping capacity are planned (E4 in [PLAN](../PLAN.md)).
- Local prices are not part of the multiplayer snapshot's price band check beyond `price_loc` itself, and the Market window on a client shows host values only after the first snapshot.
- Basic-need imports are unlimited and unaffected by the input-purchase pool; only demand is recorded.
- Only five goods exist; wood, fuel and tools are planned.
