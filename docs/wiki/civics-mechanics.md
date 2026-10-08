# Mayor, civics and world events: how it works

This page explains the rules behind the mayor's side of Murmur: approval, petitions and promises, elections, advisors, milestones, loans, tribes, seasons and random world events. The raw data tables (every petition, milestone, loan, season and event) are generated and live in [civics.md](civics.md) and [events.md](events.md). This page explains how the code uses them. War and diplomacy are covered in [war.md](war.md).

Conventions used below:

- "Per second" means one call of `City._second()`, which runs once per simulated second per town (`City.tick` accumulates `acc` and calls it when `acc >= 1.0`). One in-game day is `DAY_SECS = 60.0` sim seconds, so a day is 60 `_second()` calls.
- Function names are given as `File.function` or `City.function` so you can jump to them. All the mayor rules live in `client/scripts/city.gd`; the static data lives in `client/scripts/civics.gd` and `client/scripts/events.gd`.
- Only a human-controlled town (`City.human == true`) has a mayor. Planner-only neighbours never raise petitions, hold elections or collect milestones (`_second()` guards `_civics()` and `_milestones()` with `if human`; `_raise_petition()` and `_new_day()` check `human` themselves).

## Summary

- Approval is a slowly moving number between 0 and 1. Each second it moves at most 0.004 towards a target built from city mood, income, crime, tribe opinion, reputation and penalties (`City._civics`).
- Tribes send petitions. Accepting one creates a promise with a deadline in days. Delivering it raises favour and reputation; missing it, or ignoring or declining a petition, lowers them.
- An election runs at the end of every 28-day year. The vote is approval plus or minus up to 4 points. Under 50% the game is over.
- Events are picked at random every 35 to 75 seconds (scaled by difficulty), weighted by their `w`, by the season and by the town size. Their modifiers merge with policy, tribe, season and war modifiers in `City._collect_mods`.
- Loans, milestones, advisors and a 30-line news log round out the office.

## The mayor's office

The Mayor's office is a window (Windows menu, "Mayor's office", entry 3 in `Hud.WIN_KEYS`). Built by `Hud._mayor` and refreshed by `Hud._mayor_tick`:

| Part | What it shows | Code |
|---|---|---|
| Approval bar | `approval * 100` | `Hud._mayor_tick` |
| Rally button | "Rally $150"; disabled when `rally_used`, more than 7 days to the election, or coins below `Civics.RALLY_COST` | `Hud._mayor_tick`, `City.rally` |
| Election line | days to the election, polling percentage, promises kept and broken, last vote | `Hud._mayor_tick` |
| Decisions tab | open petitions, offers, demands and recovery offers (rebuilt when `pet_ver` changes) | `Hud._rebuild_decisions` |
| Advisors tab | the output of `City.advisors()` | see Advisors |
| Goals tab | town rank and the milestone checklist | see Milestones |

Every decision button goes through `Cmd.run("answer", [idx, bool])`, `Cmd.run("rally")` and `Cmd.run("loan", [k])`, which validate the arguments and call `City.answer`, `City.rally` and `City.take_loan`. This is also the multiplayer route (see [MULTIPLAYER.md](../MULTIPLAYER.md)).

### Town rank

`Civics.rank(peak)` returns the highest entry of `Civics.RANKS` whose threshold is at most the peak population: Hamlet 0, Village 30, Town 80, City 200, Metropolis 500. Rank follows `peak`, the highest population ever reached (`peak = maxf(peak, pop)` every tick), so it never falls.

## Approval

`City._civics` runs once per second for a human town. After handling promises, petitions and the petition timer (below) it computes a target and nudges `approval` towards it:

```
op     = sum over tribes of  tribe_share[k] * (tribe_mood[k] - 0.5)

target = 0.35
       + 0.5  * mood
       + 0.08 * clamp(income / 2.0, -1, 1)
       - 0.1  (if coins < 0)
       - 0.1  * crime
       + 0.3  * op
       + rep
       - (tax_r - 0.12) * 1.5      (only if tax_r > 0.12)
       - 0.04  * wars()
       - 0.012 * min(war_battles(), 12)

approval = clamp( move_toward(approval, target, 0.004), 0, 1 )
```

Term by term:

| Term | Meaning | Where it comes from |
|---|---|---|
| `0.35` | base | constant |
| `0.5 * mood` | city happiness, 0 to 1 | `City.mood`, set in `_second` (see below) |
| `0.08 * clamp(income/2, -1, 1)` | net income per second; reaches the full +/-0.08 at +/-2 coins per second | `City.income` from `_money` |
| `-0.1` if `coins < 0` | being in debt | `City.coins` |
| `-0.1 * crime` | citywide crime level 0 to 1 | `City.crime`, `_crime` |
| `0.3 * op` | share-weighted tribe opinion minus the neutral 0.5 | `City._tribes` fills `tribe_mood` and `tribe_share` |
| `rep` | reputation from promises, rallies, victories | `City.rep`, clamped to -0.3..0.3 |
| `-(tax_r - 0.12) * 1.5` | household tax above 12%. At 20% this is -0.12 | `City.tax_r` |
| `-0.04 * wars()` | one term per war being fought | `City.wars` counts `treaty == "war"` |
| `-0.012 * min(war_battles(), 12)` | war weariness: `war_battles` sums `war_n` over current wars; one count per 20 s of war | `City.war_battles` |

Because `approval` only moves 0.004 per second, it can change by at most 0.24 per day. A new town starts at `approval = 0.6`. Approval is clamped to 0..1.

Only the residential tax appears in the approval target. Commercial and industrial taxes reach approval indirectly: through the business and union tribes' opinions (`_tribes`) and through mood-related effects.

### Mood, the biggest term

`mood` is set in `_second()` and moves at most 0.05 per second towards its own target:

```
target = 0.72
       - shop_gap * 0.15
       - min(burning * 0.03, 0.2)
       - (tax_r - 0.10) * 2.0
       - unemp * 0.3
       + news_signal * 0.3
       - WEATHER_PENALTY[weather]
       - sum over "need" stats  (w * _need(stat))
       + sum over "bonus" stats (w * coverage(stat))
       - 0.08 * congestion
       - 0.25 * sick / pop
       - 0.03 (pop >= 40 and local food share < 0.3)
       - 0.15 * pollution
       - 0.25 * max(crime - 0.1, 0)
       - 0.1  * clamp((avg_commute - 12) / 30, 0, 1)
       - 0.04 * clamp((avg_shop - 8) / 20, 0, 1)
       + mod("mood")
```

`WEATHER_PENALTY` is `{clear 0, rain 0.05, heatwave 0.1, storm 0.2, snow 0.05, fog 0.02}`. This is where the "Mood -5%" in the rain description comes from. `mod("mood")` is the sum of all `mood` modifiers from policies, active events, tribes, the season and war (see Modifier merging). Stat weights `w` and kinds are in [stats.md](stats.md). Below mood 0.2 the town is in protest (`protest = mood < 0.2`), income halves (`_money`: `f = 0.5 * RATE` while protesting), and a family leaves each second. Each citizen's own mood is `mood + bias - 0.15 (unemployed) - 0.08 (commute over 28)`.

### Tribe opinion, the second biggest term

See Tribes below. The opinion of a tribe is half its members' average mood and half its satisfaction score, so mood and approval reinforce each other.

## Reputation and favour

Two hidden numbers carry the history of your decisions:

- `rep` is a single city-wide reputation added directly to the approval target. Clamped to -0.3..0.3. It drifts to zero by 0.0004 per second (about 0.024 per day).
- `favor[tribe]` is a per-tribe bonus or penalty added to that tribe's satisfaction score before the opinion is computed. Clamped to -0.4..0.4 and drifts to zero by 0.0008 per second (about 0.048 per day).

Both decay in `City._civics`. The events that change them:

| Event | `favor[tribe]` | `rep` | Function |
|---|---|---|---|
| Accept a petition | +0.05 | none | `City.answer` |
| Decline a petition (or let it expire) | -0.12 | -0.02 | `City.answer` with `yes = false` |
| Promise kept | +0.20 | +0.06 | `City._civics` |
| Promise broken | -0.30 | -0.10 | `City._civics` |
| Fund a rebuild after a disaster | none | +0.04 | `City.answer` (kind `recover`) |
| Campaign rally | none | +0.07 | `City.rally` |
| Win a war by occupation | none | +0.10 (winner), -0.10 (loser) | `Diplo.surrender` |

Because `rep` goes straight into the target, +0.07 from a rally raises the target by 7 points. Note that the target is only approached at 0.004 per second, so a rally during the last week is worth it but not instant.

## Petitions and promises

### Raising a petition

`pet_t` starts at 40 and counts down by 1 each second in `_civics`. At zero it is reset to a random 70 to 130 seconds and `City._raise_petition` runs. The petition is dropped immediately (nothing happens until the next timer) if any of these hold:

- the town is not human, or `pop < 12`, or three or more decisions are already open (`petitions.size() >= 3`; offers, demands and recovery offers count in this list).

Otherwise it builds a list of candidates from `Civics.PETITIONS` and removes any that fail one of these tests:

1. Its `id` is already open (in `petitions` or `promises`), or it was raised in the last 6 days (`pet_recent`), or `pop` is below its `minpop` (default 15 if the entry has none).
2. The tribe's current `tribe_share` is below 0.05.
3. The petition has a `crime` field and `crime` is below it (only `lamps`, 0.2), or a `poll` field and `pollution` is below it (only `clean_air`, 0.15). These petitions only appear when the problem exists.
4. Its need is already met (`_met`). For a `build` need the rule is different: the building must be unlocked (`unlocked`) and the town must have fewer than `1 + pop / 100` of that building.
5. For the festival petition (`need.event`), it is skipped when `mood > 0.55`.

One candidate is chosen uniformly at random. It gets `kind = "petition"` and `expires = day + 2`, a headline, a log line and the "petition" sound.

### Need types

`City._met(need, have)` evaluates the need each second while a promise is open:

| Need key | Condition |
|---|---|
| `build` | the number of connected buildings of that id is greater than `have` (the count when you accepted) |
| `cov` `[metric, min]` | average coverage `cov[metric]` is at least `min` |
| `tax` `[r/c/i, max]` | that tax rate is at most `max + 0.001` |
| `policy` | the policy is on |
| `policy_off` | the policy is off |
| `unemp` | unemployment is at most the value |
| `event` | the named event is currently active (`is_active`); for the festival that means it must be running at the moment of the check |

`Civics.need_text` produces the readable text for the Decisions tab.

### Answering

`City.answer(idx, yes)` (reached through `Cmd.run("answer")`):

- For petitions: yes sets `deadline = day + days`, records `have`, appends the entry to `promises` and gives +0.05 favour. No gives -0.12 favour and -0.02 reputation.
- For kinds `offer` and `demand` it forwards to `Diplo.resolve` (see [war.md](war.md)).
- For kind `recover` yes pays the rebuild cost, calls `_rebuild` and counts as a survived disaster; no clears the ruins and does not.

A petition that sits unanswered past `expires` (`day > expires`) is auto-declined with `answer(idx, false)` inside `_civics`, which costs the same -0.12 favour and -0.02 reputation as a refusal.

### Delivery and failure

Each second `_civics` checks every promise:

- if `_met` is true the promise is removed, `kept += 1`, favour +0.20, rep +0.06, a "good" sound and a headline;
- else if `day > deadline` it is removed, `broken += 1`, favour -0.30, rep -0.10 and a "bad" sound.

The deadline is inclusive of the day it names: accepting a 3-day petition on day 10 sets the deadline to 13, and it breaks on day 14. A non-build need that is already satisfied when you accept (it may have become true since it was raised) is credited as kept on the next second. For build needs the `have` baseline prevents this: you must construct a new building.

`kept` feeds the milestones `kept1` and `kept5`; `kept` and `broken` are shown on the election line.

## Elections and game over

- `next_election` starts at `Civics.YEAR_DAYS + 1 = 29` and grows by 28 after each vote. The first election is on day 29, then 57, 85 and so on.
- `City._new_day` (called when the day counter increments in `tick`) posts "Election in 3 days. Polls put you at N%." when `next_election - day == 3`.
- On the election day: `vote = clamp(approval + uniform(-0.04, 0.04), 0, 1)`, stored in `last_vote`; `next_election += 28`; `rally_used = false`.
- `vote >= 0.5` wins: `elections_won += 1`, a headline and the "chime" sound. Otherwise `over = "Voted out. You won only N% of the vote on day D."`.

### Ways to lose

`City.tick` sets `over` and then stops simulating that town (`tick` returns at once when `over != ""`):

| Condition | Message | Where |
|---|---|---|
| lost election (vote under 50%) | "Voted out..." | `_new_day` |
| `coins < DEBT_LIMIT` (-150) | "Bankrupt. The city could not pay its bills." | `tick` |
| `peak >= 10` and `pop < 1` | "Everyone left. The city is empty." | `tick` |

Planner-only towns cannot lose: for a non-human town `tick` instead lifts `coins` to at least 30, and `_new_day` returns before the election. When `over` is set, pressing R calls `Main.new_game()`, and the game does not autosave a finished city.

### Campaign rally

`City.rally` succeeds only when `rally_used` is false, `coins >= 150` and `next_election - day <= 7`. It costs `Civics.RALLY_COST = 150`, sets `rally_used`, adds +0.07 to `rep` and logs "Campaign rally in the square.". The tooltip text in the window says "+7% approval", which matches the reputation bonus but not an instant jump (see Approval). `rally_used` is reset at each election.

## Advisors

`City.advisors()` returns `[name, text, happy]` rows for the Advisors tab; `happy` selects the "(ok)" or "(worried)" marker. It is recalculated every UI refresh, not stored. The text of each advisor is chosen by an if-chain where the first matching condition wins:

| Advisor | Priority of messages (first match wins) | Happy when |
|---|---|---|
| Treasurer | `income < -0.2` (losing money, suggests raising taxes or a loan); `coins > 1500` (suggest spending); any open loans (repayment per second); otherwise a generic line | `income >= 0` |
| Police & fire chief | fires burning; `crime > 0.3`; fire cover under 0.6 with `pop > 30`; otherwise calm | no fires and `crime <= 0.3` |
| City planner | `congestion > 0.3`; `avg_commute > 18`; more than 4 unemployed; otherwise the demand line (homes, shops, industry) | `congestion <= 0.3` and `avg_commute <= 18` |
| Health & welfare | sick citizens; `pop >= 30` and local food share under 0.4; the first stat (in `Catalog.METRICS` order) whose `_need` is over 0.3; otherwise "healthy and fed" | `sick_n == 0` |
| Campaign manager | election countdown and poll; warns "We'd lose today!" when `approval < 0.5` (mentions a rally when 7 or fewer days remain and the rally is unused); mentions the household tax when `tax_r > 0.12`; counts open petitions | `approval >= 0.5` |
| General | only while `wars() > 0`: war length in 20-second units, weariness, military advice | always "worried" |

Advisors can disagree with each other; they only describe one dimension each.

## Milestones

`City._milestones` runs each second for a human town. For each entry of `Civics.MILESTONES`: if it is not yet in `done_ms` and `float(get(stat)) >= v`, then `done_ms[id] = day`, `coins += reward`, a "Milestone: ..." headline (with "(+$N)" when the reward is non-zero), a log line and the "chime" sound. The `stat` names are City properties read with `get()`:

| `stat` | City property | Notes |
|---|---|---|
| `peak` | `peak` | highest population ever |
| `mood` | `mood` | current mood |
| `approval` | `approval` | current approval |
| `kept` | `kept` | promises kept |
| `elections_won` | `elections_won` | |
| `exported` | `exported` | cumulative units sold abroad |
| `avenues` | `avenues` | current avenue tile count |
| `land_avg` | `land_avg` | average land value, 0 to 1 |
| `disasters_survived` | `disasters_survived` | incremented when a recovery offer is accepted and paid |
| `coins` | `coins` | the "Fat treasury" milestone pays 0 |

The full table with rewards is in [civics.md](civics.md#milestones). Each milestone fires once and `done_ms` is saved. A milestone whose stat is already high when the game loads is only collected if it is not in `done_ms`.

## Loans and debt

`City.take_loan(k)` (`Cmd` command `loan`) uses `Civics.LOANS`:

- It fails when three loans are already open (`loans.size() >= 3`) or when `peak < minpop` of the loan. The check is against `peak`, not the current population.
- `total = amt * (1 + rate)`, a flat interest charge, not compounding. The loan is stored as `{n, left: total, pay: total / (days * 60)}`.
- You receive `amt` coins immediately.
- Each second `_second` subtracts `pay` from `left`; when `left <= 0` the loan is removed with a log line. The repayment is also a budget line, `Loan repayments`, in `_money` (`e_loan`), so it is part of `income` and is charged to `coins` through `coins += income * dt`.

You can take the same loan again (nothing prevents duplicates), up to three at once. There is no early repayment function.

| Loan | Amount | Term | Rate | Repay total | Per second | Min peak pop |
|---|---|---|---|---|---|---|
| Small loan | 500 | 8 d | 10% | 550 | 1.146 | 0 |
| Bank loan | 1500 | 16 d | 18% | 1770 | 1.844 | 60 |
| City bond | 4000 | 40 d | 25% | 5000 | 2.083 | 150 |

The "per second" column is computed here as `total / (days * 60)`.

Debt rules: `coins < 0` costs 0.1 approval; `coins < DEBT_LIMIT = -150` ends the game. Events cannot push you deeper than -40: the instant `coins` and `coins_pop` effects in `City.trigger` use `maxf(coins + delta, minf(coins, -40.0))`. In war, unpaid troops also desert when `coins < -50` (see [war.md](war.md)).

## Tribes

Every citizen has one tribe, rolled at spawn by `City._roll_tribe` from the weights `w` in `Catalog.TRIBES`: church 14, union 30, business 12, artists 8, rebels 10, club 26. The table of what each tribe wants is in [civics.md](civics.md#tribes).

`City._tribes` runs each second, before `_collect_mods`:

1. It counts citizens and averages their moods per tribe.
2. It computes a satisfaction score `sat[k]` per tribe (formulas below) and adds `favor[k]`.
3. Opinion: `op = clamp(0.5 * avg_member_mood + 0.5 * sat, 0, 1)`; with no members the average defaults to 0.6.
4. It stores `tribe_mood[k] = op` and `tribe_share[k] = members / pop`.
5. A tribe is only active when `pop >= 20` and `share >= 0.08`. Active tribes with `op > 0.65` are content and with `op < 0.38` are unhappy; in between nothing happens.

Satisfaction formulas (`cov[...]` is average coverage, see [stats.md](stats.md)):

| Tribe | `sat` |
|---|---|
| church | `0.5 + (0.3 if a Church exists else -0.2) - crime * 0.3` |
| union | `0.6 - unemp * 1.5 - (tax_i - 0.1) * 2.0 + (0.15 if a Union hall exists)` |
| business | `0.6 - (tax_c - 0.1) * 3.0 - (tax_i - 0.1) * 2.0 + com_dem * 0.1 + market * 0.2 + (0.15 if a Chamber exists)` |
| artists | `0.3 + cov["culture"] * 0.7` |
| rebels | `0.6 - 0.25 (curfew) - 0.25 (stop_search) - 0.2 (protest) + news * 0.2` |
| club | `0.3 + cov["leisure"] * 0.6` |

Effects (collected in `tribe_mods` through `_tm`, which multiplies keys ending in `_mult` and adds the rest):

| Tribe | Content | Unhappy |
|---|---|---|
| church | `mood +0.02` | `mood -0.02` |
| union | `prod_mult x1.05` | `prod_mult x0.9` |
| business | `sales_mult x1.08` (and `goods_mult x1.0`) | `sales_mult x0.9`, `goods_mult x0.9` |
| artists | `tour_mult x1.2` | `tour_mult x0.8` |
| rebels | nothing | `crime_add +0.1` |
| club | `mood +0.02` | `mood -0.02` |

When a tribe newly becomes angry a line "<Tribe> angry." is logged (compared with the previous second's `tribe_note`). Tribe opinion is also an input of the planner (`_plan_service`: if a faction building's tribe has `tribe_mood < 0.5` and a share above 0.1 it adds 0.6 to that building's score).

## Seasons

`City._second` derives the season from the day: `season = int((day - 1) / 7) % 4`, so days 1 to 7 are Spring, 8 to 14 Summer, 15 to 21 Autumn, 22 to 28 Winter, and then it repeats. A change posts a headline and a log line. Each entry of `Civics.SEASONS` has:

- `mods`: merged into the global modifiers every second (see below).
- `harvest`: the farm output multiplier (Spring 0.6, Summer 1.0, Autumn 1.8, Winter 0.2).
- `ev`: event weight multipliers used by `WorldEvents.pick`. A missing key means 1.0, a value of 0.0 removes the event for that season.
- `grass`: the tile tint colour, used by the renderer (`wl.set_season`).

The values are in [civics.md](civics.md#seasons). Elections fall at the end of winter, because `YEAR_DAYS = 28` is four seasons of seven days.

## Modifier merging

`City._collect_mods` rebuilds the `mods` dictionary every second (and whenever a policy toggles or an event starts or ends). It merges these sources in this order:

1. Every enabled policy: `Catalog.POLICIES[k]["mods"]` ([policies.md](policies.md)).
2. Every active timed event: the stored scaled `mods` of each entry in `active`.
3. `tribe_mods` from `_tribes`.
4. The current season's `mods`.
5. If `wars() > 0`: `mood: -0.03 * wars() - 0.004 * min(war_battles(), 15)`.
6. For each alliance: `cov_defence: +0.25` (one per allied town, so they stack).

`_add_mods` rule: a key ending in `_mult` multiplies (missing starts at 1.0); any other key adds (missing starts at 0.0). `City.mod(k)` reads a key and returns 1.0 for a missing `_mult` key and 0.0 otherwise. Keys used in the code include `mood`, `income_add`, `cov_<metric>`, `dem_res/com/ind/off`, `speed_mult`, `upkeep_mult`, `sales_mult`, `goods_mult`, `office_mult`, `prod_mult`, `tour_mult`, `crime_mult`, `crime_add`, `poll_mult`, `immig_mult`, `fire_mult`, `build_mult`, `tax_mult`, `grant_mult` and `insured`.

## Random world events

Data is in `WorldEvents.EVENTS` ([events.md](events.md)). The catalogue categories are Weather, Economy, Social, Disaster and Civic (`WorldEvents.CATS`).

### Scheduling

Each town has its own timer `ev_t`, starting at 50 seconds. In `City.tick`:

```
ev_t -= dt
if ev_t <= 0:
    ev_t = uniform(35, 75) * ev_scale
    id = WorldEvents.pick(rng, pop, active_ids, recent, day, bt, season.ev)
    if id != "": trigger(id)
```

`ev_scale` comes from the difficulty chosen in the setup screen (`Main._fresh`): Relaxed 1.5, Normal 1.0, Hard 0.7. Higher means longer gaps between events. The same index sets the starting coins to 600, 300 and 150. `ev_scale` is saved with the town.

### Choosing

`WorldEvents.pick` builds a weighted list. An event is excluded if any of these hold:

- its `needs` building (a Military base for the air show, conscription, deployment and base review events) is not in the town's building index `bt`;
- the effective weight `w * season_multiplier` is 0 or less (this removes `fire`, whose `w` is 0, and `festival`, the player-only event);
- `pop < minpop`;
- the same event is currently in `active`;
- it fired fewer than 2 days ago (`day - recent[id] < 2`).

It then draws `r = randf() * total` and walks the list subtracting weights. The returned id is empty if nothing is eligible, which means that timer cycle does nothing. Probability of an event is its weight divided by the sum of the eligible weights, so an event's real chance depends on the town size and season, not just its `w`.

`prison_break` is special-cased: `trigger` refuses it unless the town has a prison, but `pick` does not check that, so the draw can be wasted (nothing happens that cycle and `recent` is not set).

Fires use a separate timer, `next_fire`: after each ignition it is set to `uniform(60, 110) / (1 + blds/80) / max(mod("fire_mult"), 0.2) / clamp(blds/14, 0.2, 1)` seconds (`City._fires`). Small towns rarely burn; summer's `fire_mult` 1.3 and the heatwave's 2.5 shorten the gap. A burning cell is put out after 3 s if covered by a fire station, after 9 s in rain or storm, and is destroyed after 14 s; each second it has a `dt * 0.12` chance to spread to a neighbour.

### Applying

`City.trigger(id)` does the following in order. The sandbox "World events" menu calls it directly (`Hud._on_event_menu`), so a player-triggered event ignores `minpop` and the cooldown:

1. A `needs` building is required (`bt`), and `prison_break` needs a prison; otherwise it returns false.
2. If the event has a `cost` (only `festival`, $40) it needs the coins and must not already be active; the cost is paid.
3. Softening: if the event has a `scale` stat, `k = 1 - 0.7 * cov[scale]` (a full coverage cuts to 30%). Otherwise `k = 1`. Note this applies to the whole event, including events that would otherwise help you (see Open questions).
4. Timed modifiers: if `dur > 0` and the event has `mods`, each value is scaled (`1 + (v - 1) * k` for `_mult` keys, `v * k` otherwise) and stored in `active` as `{id, left: dur, mods}`. Re-triggering an active event refreshes `left` and the mods. `_collect_mods` is called.
5. Weather: if the event has a `weather` key, `sig.set_weather(weather, dur)`.
6. Instant effects (`inst`):

| `inst` key | Effect |
|---|---|
| `coins` | `coins = max(coins + v * k, min(coins, -40))` |
| `coins_pop` | the same with `v * max(pop, 5) * k` |
| `ignite` | `round(v * k)` calls to `ignite()` (random unburnt building) |
| `damage` | each burnable building has chance `v * k` to lose a level (`_damage`, `_hit`) |
| `destroy` | `v` random buildings are ruined (`_destroy`, not scaled) |
| `damage` or `destroy` | also calls `_offer_recovery` (see below) |
| `tornado` | spawns `twister` at a map edge moving at speed 3 with a random drift; `_twister` ruins buildings and cuts wires and pipes along its path |
| `infect` | `v` random citizens become sick for 25 to 40 s (`_sickness` handles spread) |
| `blackout` | one random power plant is added to `offline` for 40 s |
| `citizens` | positive: up to `v` calls to `_spawn` (only if a home has space); negative: removes random citizens |
| `news`, `market` | `sig.bump(...)`, which adds to the signal clamped to -1..1 |

7. `recent[id] = day`, headline `msg`, and a log line `"<name>: <msg>"`.

### Expiry

Each tick every `active[i].left` falls by `dt`. When any reaches 0 the entry is dropped, "<name> ended." is logged and `_collect_mods` is called. Because only events with both `dur > 0` and `mods` enter `active`, effects such as `power_outage` (an `inst` blackout with `dur` 30 but no `mods`) never appear in `active`; the outage itself lasts the `offline` timer of 40 seconds.

### Weather and the signals

`Signals` (`signals.gd`) holds the world conditions, shared by all towns of a region (one `Signals` object created in `Main`, passed to each `City`):

- `market` and `news` are floats in -1..1 which decay towards 0 by 0.02 per second (`Signals.tick`, called once per sim step). A bump of 0.7 therefore takes 35 seconds to fade. `market` feeds `econ = 1 + 0.5 * market` in `_money` (so a boom of +0.7 is +35% to incomes at its peak) and the demand formulas; `news` feeds mood (`news * 0.3`) and the rebels' satisfaction.
- Weather is one string with a countdown, set by the last weather event that fired (`set_weather`) and reset to "clear" when its timer ends. Because the object is shared, weather in one town is weather in all towns and a later weather event overwrites an earlier one, including the earlier one's countdown. Weather drives `WEATHER_PENALTY` (mood), fire behaviour (rain and storm), and the rain, snow and other overlays in `Main._draw`.

### Recovery offers

After `damage` or `destroy` events, and after raids (`Diplo._raid`) and tornadoes, `_offer_recovery(cause)` runs if at least two buildings were lost or damaged since the last decision (`ruins.size() >= 2`). It adds (or updates) a `recover` decision costing `20 * ruins.size()` coins which expires in 2 days. Funding it calls `_rebuild` (restores the buildings and zone levels from `ruins`) and gives +0.04 reputation. Declining or ignoring clears `ruins`. Either answer counts as one survived disaster. Destroyed services are not restored by letting the city recover on its own.

## News feed and logs

There are three text feeds:

| Feed | Storage | Size | Shown |
|---|---|---|---|
| Event log | `City.event_log`, each entry `"D<day> HH:MM  text"` (`City.stamp`), newest first via `_log` | 30 entries, oldest dropped | first 14 in the log label of `Hud` |
| Headline | `City.msg`; `Main` copies the current town's `msg` into `headline` and clears it every sim step | one line | the ticker at the top |
| Murmurs | `City.murmurs`, citizen thoughts every 5 to 11 s (`_murmur`) | 20 entries | first 5 in the HUD |

Off-screen towns blank their `msg` each step, so their headlines never display. The `news` signal is a mood input and not this feed. Sounds (`alarm`, `petition`, `good`, `bad`, `chime`) are queued in `City.sounds` and played by `Main` for the active town.

## Saving and loading

`Main.save_game` writes `user://murmur_save.bin` (`store_var`, version 2) with each town's `City.to_dict()`, the index of the current town, `sig.v` (the market and news values) and the world seed. It runs:

- every time the current town's day counter changes (in `Main._process`, when `city.over == ""`),
- when the window is closed (`NOTIFICATION_WM_CLOSE_REQUEST`),
- when starting a new game from a live game (`new_game`); a finished game's save is deleted instead.

It does nothing in networked play. `load_game` rejects files whose `v` is not 2.

The civic state saved per town is the part of `City.SAVE_KEYS` listing: `approval`, `rep`, `favor`, `petitions`, `promises`, `pet_recent`, `kept`, `broken`, `next_election`, `elections_won`, `rally_used`, `last_vote`, `season`, `loans`, `done_ms`, `disasters_survived`, `recent`, `active` (with its scaled mods), `ruins`, `offline`, `ev_scale`, and also `day`, `coins`, `mood`, taxes and `policies`. `from_dict` calls `_collect_mods` after loading.

Not saved, recomputed or reset on load: the countdowns `pet_t`, `ev_t`, `next_fire` and `murmur_t` (restart at their defaults), `tribe_mood` and `tribe_note` (rebuilt next second), the event log, murmurs, the weather string, the twister and all runtime army fields.

## Where in the code

| Topic | Location |
|---|---|
| Static data: seasons, petitions, milestones, ranks, loans, rally cost | `client/scripts/civics.gd` (`Civics.SEASONS`, `PETITIONS`, `MILESTONES`, `RANKS`, `LOANS`, `RALLY_COST`, `YEAR_DAYS`) |
| Event catalogue and `pick` | `client/scripts/events.gd` (`WorldEvents.EVENTS`, `pick`, `describe`) |
| Approval, promises, petition timer | `City._civics` |
| Petition creation, answers | `City._raise_petition`, `City.answer`, `City._met`, `City._open_ids` |
| Elections, rally | `City._new_day`, `City.rally`, `City.tick` (game-over checks) |
| Advisors | `City.advisors` |
| Milestones | `City._milestones` |
| Loans, budget | `City.take_loan`, `City._money` (`e_loan`, `budget_lines`) |
| Mood | `City._second` (the `target` block) |
| Tribes | `City._tribes`, `City._tm`, `City._roll_tribe`, `Catalog.TRIBES` |
| Modifier merge | `City._add_mods`, `City._collect_mods`, `City.mod` |
| Event scheduling and effect | `City.tick`, `City.trigger`, `City._damage`, `City._destroy`, `City._twister`, `City._sickness`, `City._fires` |
| Recovery | `City._offer_recovery`, `City._rebuild` |
| Signals and weather | `client/scripts/signals.gd`, `City.WEATHER_PENALTY` |
| Command entry points | `client/scripts/cmd.gd` (`answer`, `rally`, `loan`) |
| UI | `Hud._mayor`, `Hud._mayor_tick`, `Hud._rebuild_decisions`, `Hud._on_event_menu` |
| Save and load | `Main.save_game`, `Main.load_game`, `City.to_dict`, `City.from_dict`, `City.SAVE_KEYS` |

## Open questions

- `police_raid` (scale `justice`), `heatwave` (scale `health`) and similar entries use the same softening factor `k = 1 - 0.7 * coverage` for the whole event, so a beneficial event that has a `scale` (the police raid is the only positive one) is weakened by high coverage. This is how `City.trigger` reads, but it may not be intended.
- The event descriptions in `events.gd` state mood effects such as "Mood -10%" for the heatwave that come from `WEATHER_PENALTY`, not from the event `mods`. The descriptions for `power_outage` ("40 seconds") and its `dur` (30.0) differ; the code uses the 40 s `offline` timer.
- `prison_break` can be drawn by `WorldEvents.pick` in a town with no prison and then does nothing (wasted cycle). It is unclear whether a `needs`-style check was meant for it.
- The rally tooltip promises "+7% approval", but the code adds 0.07 to `rep`, which only raises the target that `approval` then approaches at 0.004 per second.
- Fixed: declining a `recover` offer no longer counts toward the "Survivor" milestone.
- Weather is a single global value shared by every town of a region, but each town rolls its own events, so several towns can overwrite each other's weather. Whether this is intended for multi-town regions is not documented.
