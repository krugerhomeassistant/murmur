# Market

One shared exchange sets the price of the five tradable goods: crops, food, goods, ore and metal. Towns do not trade pairwise; each town reports what it offers and needs every sim second and the price of each good follows the balance. Implementation: `client/scripts/market.gd` (class `Market`), owned by `Signals` (`sig.mk`), used by `City._trade`. Test: `client/tests/market.gd`.

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
| Town trade | `City._trade` (`city.gd`) |
| Snapshot and save | `Market.brief`, `Market.apply_brief`, `Market.to_dict`, `City.to_dict`, `Main.save_game` |
| Window | `Hud._market_win`, `Hud._market_refresh`, `Hud._spark` |

## Open questions
- The market has no distance: prices are the same in every town and trade needs no road. Regional prices and trade routes are planned (E4 in [PLAN](../PLAN.md)).
- Basic-need imports are unlimited and unaffected by the input-purchase pool; only demand is recorded.
- Only five goods exist; wood, fuel and tools are planned.
