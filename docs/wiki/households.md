# Households: savings, cost of living and unrest

Every citizen carries savings (`Citizen.wealth`, coins). Wages come in, bills go out, and the balance decides whether a home can be upgraded and whether the town is calm. Prices come from the [market](market.md), so a supply crisis or a famine shows up as inflation. Implementation: `City._households`, `City._can_upgrade` (`client/scripts/city.gd`). Test: `client/tests/households.gd`.

## Money in and out (once per sim second, per citizen)
```
net wage = WAGE * wage_ix * (1 + 0.3 * edu coverage) * (1 - tax_r) * tier(sector of the workplace)
bills    = 0.05 * food price + 0.03 * goods price + RENT * tier of the home
wealth  += net wage - bills          (unemployed citizens earn nothing)
```
`WAGE` 0.30, `RENT` 0.04. Workplace tiers (`WAGE_TIER`): office 1.8, mine 1.2, industry 1.1, commerce 1.0, farm 0.8, orchard/ranch/greenhouse/fish farm 0.9, services 1.0. Food and goods prices are the live market prices, so the basic basket costs `0.075 + 0.06` per second at base prices. New arrivals bring 30-60 coins. Savings above 150 decay by 0.4% of the excess per second (the well-off spend and invest elsewhere). Savings under `BROKE` (8) mean the household cannot make ends meet.

## Inflation
- `cpi` is the cost-of-living index: `0.6 * food ratio + 0.4 * goods ratio` (market price against base), smoothed at 2% per second.
- `wage_ix` follows `cpi` at `WAGE_LAG` 0.003 per second (about five minutes), so wages trail prices: during a surge the real wage `wage_ix / cpi` falls and households drain savings; afterwards wages catch up.
- Prices jump through the [Supply crisis](events.md) event (food x1.7, goods x1.5, crops x1.4, fading over minutes), through famine (a town that cannot feed itself raises the food price) and through the world market signal. The [Price slump](events.md) event does the opposite.

## What savings do
| Effect | Rule |
|---|---|
| Home upgrades | A residential building goes up a level only when its residents' average savings reach `UPGRADE_WEALTH` (20) x current level; they then invest half of that each. Homes with no residents upgrade as before. The town treasury still pays its share as before. |
| Business upgrades | Commercial, industrial and office buildings upgrade when the town's average savings reach 10 x current level (customers must have money). |
| Mood | `-0.15 * broke share` once the town has 20 residents. |
| Crime | `+0.25 * broke share` added to the base crime level. |
| Riots | When more than half the households are broke in a town of 30 or more, `protest` turns on (as when mood drops under 20%): tax and tourism income halve. |
| Tax base | Residential tax is scaled by `clamp(wage_ix, 0.7, 1.6) * (1 - 0.4 * broke share)`: wages carry the tax base, broke households pay less. |

## Policy and planner
The policy [Cost-of-living payments](policies.md) gives every broke household 0.12 coins per second (upkeep 2.0). Planner towns switch it on when more than 30% of households are broke, the treasury is over 250 and income over 1; they switch it off under 10% broke or when income drops under 0.2.

## Landlords and the savings tax
Each second every household pays rent (`RENT` times its home's tier). The rents are pooled and paid out equally to the households whose savings are in the top quarter (at least 4 residents are needed), so rent moves wealth upward and is conserved (`hh.rent` collected, `hh.rent_got` paid). The well-off already spend and invest away 0.4% per second of savings above 150; the town now taxes a share `clamp(5 * residential tax rate, 0, 1)` of that outflow into the treasury (budget line "Savings tax", `City.hh_tax`), so a 10% rate takes half and a 0% rate none. Test: `client/tests/landlords.gd`.

## Where to see it
City panel (Economy tab): "Households: average savings, median, broke and comfortable shares, prices, wages, real wage". Event feed: price events.

## Where in the code
| Topic | Code |
|---|---|
| Constants | `WAGE`, `WAGE_LAG`, `RENT`, `BROKE`, `UPGRADE_WEALTH`, `WAGE_TIER` (`city.gd`) |
| Wages, bills, statistics | `City._households` (called at the top of `City._money`) |
| Upgrade gate | `City._can_upgrade`, used by `City._grow` |
| Mood, crime, riots | `City._analyze` mood target, `City._crime`, `protest` |
| Save | citizen array element 10 (`wealth`) and key `wage_ix` |
| Price shocks | `Market.shock_by`, event key `inst.shock` |

## Open questions
- Town income (`City._money`) is still the aggregate formula; households do not pay it individually, only scale it.
- Landlords are simply the best-off quarter of households; there are no property deeds, so a home's owner is not a specific person. The savings tax is the only link from household savings to the treasury; savings do not feed the commercial tax.
- Unemployed citizens get no income unless the payments policy is on.
- No per-family view yet (households are single citizens, grouped only by home cell).
