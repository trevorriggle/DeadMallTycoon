# Dead Mall Tycoon — Core Game Mechanics Draft
*Draft v0.3 — updated April 15, 2026*

> **Archival snapshot (pre-v9 rename).** This document is a frozen design
> artifact predating the v9 fictitious-brand pass. Real retailer names in the
> flavor quotes and example tables below (Sears, KB Toys, Spirit Halloween,
> etc.) were replaced in the live codebase with fictional parallel-universe
> equivalents. Preserved as-is for mechanics context; **not** a source of
> truth for tenant strings. See `Data/Catalog.swift`,
> `Data/StartingMall.swift`, and `Data/ClosureFlavor.swift` for the
> canonical names.

---

## Time & Pacing

- Time moves in **months**, real-time. The player watches the mall breathe — visitors wandering, thoughts surfacing, the slow entropy of a dying place.
- A month takes approximately **2-3 real minutes** at default speed. A speed toggle (1x / 2x / 3x) lets you fast-forward slow periods.
- **The 1st of every month** is the economic tick: rent is collected, struggling tenants close, lease expirations trigger, new tenant offers may appear, events may fire.
- There is no overnight. The mall is always open, always populated at some level. Visitors thin out but never disappear.

---

## Starting Conditions

- Game begins **circa 1980** at a thriving mall — 95% occupied, peak foot traffic, full anchor complement.
- The player inherits the mall. They did not build it. They are now responsible for what happens to it.
- Early game the player has limited tools: decorations, reading visitor thoughts, cancelling leases. New capabilities unlock as the mall declines (or as score thresholds are hit).

---

## Score System

### Formula
```
Monthly Score = Empty Store Slots × Years Survived × Aesthetics Multiplier
```
Score accumulates every month. It is not a one-time calculation — it ticks upward continuously as long as the mall remains open.

### Empty Store Slots
The core driver. More vacant storefronts = higher monthly score. A mall with 5 tenants in 60 slots scores dramatically higher per month than one with 40 tenants.

### Years Survived
A compounding multiplier. The longer the mall stays open, the more each month is worth. Surviving year 10 scores far more per month than surviving year 1. This rewards patience and long-term management over quick vacancy grabs.

### Aesthetics Multiplier
A rating (1.0x — 3.0x) based on the presence and decay state of liminal architectural features. See Aesthetics System below.

### Foot Traffic Floor
Score is only awarded if the mall stays above a minimum visitor threshold. Drop below it — through too few tenants, too much decay, or a bad event — and the mall enters **Critical State**. No score accrues in Critical State. Prolonged Critical State triggers closure.

### Score is not money
Score is legacy. Money is survival. Both matter independently.

---

## Money System

### Monthly Bottom Line
Every mall has fixed monthly operating costs regardless of occupancy: utilities, maintenance, insurance, property tax, security. A nearly empty mall costs almost as much to run as a full one. This is the economic trap.

### Tenant Rent
Each tenant pays monthly rent. Rent revenue must cover or approach the bottom line. Shortfalls go to debt.

### Debt & Bankruptcy
The player can carry a debt ceiling — a buffer before bankruptcy is declared. The ceiling is fixed per level. Hitting it ends the session: forced closure, no score bonus, game over.

Debt can be partially cleared by:
- Accepting a tenant offer
- Selling a decoration
- Accepting a developer acquisition offer (ends the run)

### Tenant Financial Health
Tenants have their own P&L. If a tenant's foot traffic falls below their viability threshold for **2 consecutive months**, they announce closure and leave on the next 1st. The player gets a 30-day warning notification.

The player cannot prevent a natural closure. They can only influence foot traffic levels — which affects all tenants simultaneously, not individually.

---

## Tenant System

### Lease Terms
- **Kiosks / pop-ups:** month-to-month. Leave easily, arrive easily.
- **Standard stores:** 1-2 year leases. Predictable, manageable.
- **Large format stores:** 3-year leases. Harder to move out, harder to attract.
- **Anchor tenants:** 5-year leases. Their departure is a seismic event.

### Lease Expiry
When a lease expires, the player chooses: **renew** or **let go**. Letting go has no score penalty — the tenant simply leaves on the 1st of the following month, and the vacancy immediately improves the score multiplier. This is the preferred exit mechanic and the cleanest strategic play. Forced eviction exists for when you can't wait.

### Forced Eviction
The player can evict a tenant before their lease expires. **Significant score penalty.** This is the nuclear option — available but costly. The right play is almost always to wait.

### New Tenant Offers
Each month there is a chance a prospective tenant makes an offer. The player accepts or declines. Offers are generated based on:
- Current vacancy level (more vacancies = more desperate/unusual offers)
- Mall reputation (declining mall attracts declining tenant types)
- Random event triggers

Accepting a tenant fills a slot (hurts score multiplier) but adds revenue. Declining keeps the slot empty (helps score) but forgoes revenue.

### Event Examples
Events fire randomly or are triggered by conditions. They are not limited to tenant offers — the mall is subject to everything that happens to real dead malls.

**Infrastructure events (negative):**
- Burst pipes — catastrophic repair cost, affects entire wing, aesthetics decay accelerates. The worst single event in the game.
- AC failure — comfort drops, foot traffic dips, tenants complain. Cheaper than pipes but affects the whole mall.
- Roof leak — maintenance cost spike, localized wing damage.
- Broken windows — safety hazard, aesthetics decay, small repair cost.
- Storm damage — random wing impact, variable severity.

**Social events (mixed):**
- Gang activity — foot traffic drops significantly in affected wing. Realistic to the dead mall experience. Reputation penalty.
- Viral nostalgia post — traffic spike 2-3 months. Better for bottom line, worse for score.
- Urbex YouTuber — unusual visitor type, small traffic bump, may attract developer attention.
- Local news segment — "Whatever happened to..." spike. Increased city scrutiny follows.

**Regulatory events:**
- Health inspection — food court tenant at risk. Bribe, fix, or let them close.
- Structural report — wing closure required or expensive repair.
- Code violation fine — per-month penalty until resolved, mirroring real mall liability law.
- Local government pressure — escalating fines for unresolved safety hazards.

### Tenant Tiers

| Tier | Examples | Rent | Traffic Generated | Traffic Required | Notes |
|------|----------|------|-------------------|------------------|-------|
| Anchor | Department store, cinema | High | Very High | High | 5-yr lease, departure triggers cascade |
| Large format | Sporting goods, bookstore | Medium-High | High | Medium | 3-yr lease |
| Standard | Clothing, electronics, nail salon | Medium | Medium | Low-Medium | 1-2yr lease |
| Kiosk | Cell phone cases, sunglasses, MLM | Low | Low | Very Low | Month-to-month |
| Chaos | Spirit Halloween, pop-up flea market, escape room | Variable | Variable | None | Seasonal or event-driven, no lease |
| Sketchy | Vape shop, bootleg DVD, pawn satellite | Very Low | Low | None | Desperate offer, carries reputation penalty |

### Anchor Departure
When an anchor leaves (lease expiry, financial closure, or rare event):
- Foot traffic drops 20-30% **wing-wide** immediately — the anchor's wing takes the primary hit
- Secondary ripple effect mall-wide (~5-10% overall traffic reduction)
- Adjacent tenants in the same wing begin receiving closure warnings first
- Developer acquisition offer arrives within 2 months
- Score bonus for the vacancy, but survival in that wing becomes significantly harder

---

## Aesthetics System

Certain physical features of the mall carry an **Aesthetics Multiplier** that amplifies the monthly score. Features have condition states that affect their multiplier value.

### Condition States
`Pristine → Worn → Damaged → Deteriorating → Ruin`

Higher decay = higher multiplier contribution. But features in Ruin state eventually trigger a **Safety Hazard** event. Once flagged, the mall is fined a fixed amount **per month** until the hazard is resolved — mirroring real mall liability law. The player can repair (cost + multiplier reduction), remove (permanent multiplier loss), or continue paying the monthly fine and accepting the liability risk of eventual forced closure.

### Feature Examples

| Feature | Base Multiplier | Ruin Multiplier | Notes |
|---------|----------------|-----------------|-------|
| Kugel ball (floating granite sphere) | 1.15x | 1.35x (stopped spinning) | Expensive to maintain. Stopping it saves money, boosts decay multiplier. |
| Neon signage | 1.10x | 1.25x (flickering) | Flickering is peak liminal. Full dark = removed, no multiplier. |
| Skylight atrium | 1.20x | 1.40x (cracked panes) | Broken panes are a safety hazard at Ruin. |
| Indoor fountain | 1.10x | 1.30x (non-functional, pennies still in) | Non-functional beats functional for score. |
| Original terrazzo/marble flooring | 1.15x | 1.30x (cracked, stained) | Cannot be replaced without losing multiplier entirely. |
| Mall directory board | 1.05x | 1.15x (outdated listings) | Updating it resets decay and reduces multiplier. Never update it. |
| Food court seating | 1.05x | 1.15x (empty, original plastic chairs) | Only multiplies if the food court is partially or fully vacant. |
| Art installation | 1.10x | 1.20x (ignored, dusty) | Removing it for any reason loses the multiplier permanently. |

### Decoration Actions
The player can:
- **Purchase new aesthetic features** (expensive, adds multiplier)
- **Repair a feature** (costs money, reduces decay, temporarily lowers multiplier)
- **Remove a feature** (free, permanently loses multiplier)
- **Ignore a Safety Hazard** (free, risk of score penalty or closure trigger)

Decoration is one of the player's earliest and most important strategic levers.

---

## Visitor System

### Visitor Population
Visitor count is a function of:
- Number and quality of active tenants (more tenants = more visitors)
- Anchor presence (anchors drive significant traffic)
- Aesthetics score (a beautiful decay attracts a different kind of visitor)
- Active events (viral nostalgia = traffic spike; health inspection = traffic dip)
- Mall reputation (declining over time as the mall ages)

### Visitor Profiles
Each visitor has an age cohort that determines their memory pool:

- **60s+ (The Originals):** Remember the opening, the original anchor stores, the Christmas displays of the golden era. Deepest nostalgia, rarest visitors.
- **30s-50s (The Nostalgics):** The primary visitor base. Teenage memories — food court rituals, specific stores, adolescent experiences. Most common thought bubble triggers.
- **Teens-20s (The Explorers):** Remember the decline. Came here when it was already half-empty. Find it fascinating for different reasons — urbex energy, ironic appreciation, genuine curiosity.

### Thought Bubbles
Visitors generate thought bubbles as they pass specific locations:
- A closed storefront triggers a memory of what was there
- A functioning aesthetic feature triggers a sensory memory
- The food court triggers specific food memories
- The kugel ball triggers the universal kugel ball memory

Thought bubbles are generated via LLM call, contextualized by:
- Visitor age cohort
- Location in the mall (what store was here, what feature is here)
- Mall's historical tenant record (what has opened and closed)
- Current decay state

**Example thoughts:**
- *"They had a KB Toys right here. I saved up for three months for my Nintendo 64."*
- *"My mom used to drag me to the Sears. I'd spend the whole time in the tool section pretending to care."*
- *"I found this place on Reddit. I can't believe it's still open."*
- *"The fountain used to work. I threw a penny in here every single time."*
- *"This place smelled exactly like this when I was eight. I can't explain it."*

LLM calls are batched and cached — not one call per visitor per frame. A pool of contextual thoughts is generated per location per session and recycled with variation.

---

## Event System

Events fire on the 1st of certain months, triggered by conditions or random chance. They introduce narrative and chaos into the economic loop.

### Negative Events
| Event | Effect | Player Response |
|-------|--------|----------------|
| Anchor departure announcement | 30-day notice; traffic drop incoming | Prepare financially, consider acquisition offer |
| Roof leak | Maintenance cost spike; affected wing aesthetics decay faster | Repair (cost) or ignore (liability risk) |
| Health inspection | Food court tenant at closure risk | Bribe, close voluntarily, or fix |
| Structural report | Wing closure required or expensive repair | Pay, close wing, or risk Safety Hazard cascade |
| Economic downturn | Traffic drops 15-25% for 2-3 months | Survive the dip |
| Local government pressure | Fine for code violations on decayed features | Pay or fight (delays fine, adds cost) |

### Positive Events (complicated)
| Event | Effect | Tradeoff |
|-------|--------|---------|
| Viral nostalgia post | Traffic spike 2-3 months | More visitors = better bottom line, worse score |
| Urbex YouTuber | Unusual visitor type appears; small traffic bump | Attracts attention, may trigger developer interest |
| Local news segment | "Whatever happened to..." traffic spike | Increased city scrutiny; developer offer may follow |
| Ghost tour operator | Revenue offer for overnight events | Adds income, adds chaos tenant classification |
| Christmas pop-up season | Temporary vendors appear Oct-Jan | Occupancy rises, score multiplier drops seasonally |

### Tenant Opportunity Events
Each month, 0-2 prospective tenants make offers. Offer quality degrades as the mall's reputation declines:

- **Early game:** Legitimate retailers, recognizable chains
- **Mid game:** Independent stores, discount retailers, service businesses
- **Late game:** Sketchy tenants, chaos operators, Spirit Halloween, the escape room guy
- **End game:** Nobody. Or the developer.

---

## The Developer Antagonist

A faceless real estate entity that wants to redevelop the property — parking lot, condos, Amazon fulfillment center. The player's silent nemesis.

### Acquisition Offers
The developer makes periodic acquisition offers. Each offer is a lump sum score bonus — tempting, especially near collapse. Accepting ends the run immediately but banks the points toward level progression.

**Offer timing:**
- First offer arrives within 2 months of the first anchor departure
- Subsequent offers arrive every 3-4 months if declined
- Offers escalate in value as the mall weakens (the developer smells blood)
- Final offer before forced bankruptcy is the highest — designed to be genuinely tempting

### Forced Acquisition
If the player hits the debt ceiling, the developer steps in. Forced closure. No score bonus. Game over. The developer always wins eventually — the question is how long you hold them off and how much score you accumulate before you have to fold.

### Christian's Mechanic
A timed acquisition offer at near-collapse can be accepted for just enough score to unlock the next level — a calculated surrender. Sometimes selling is the smart play.

---

## Cutaway Dialogue (Christian's Addition)

Certain tenant types trigger cutaway dialogue scenes — brief narrative moments with sketchy or memorable characters who explain why they're still here despite everything.

**Examples:**
- The pager accessories guy who has been here since 1994 and insists business is picking up
- The MLM booth operator who is "actually doing really well this quarter"
- The escape room owner who chose this location specifically because of the vibe
- The woman who runs the Christian bookstore and believes God will provide foot traffic

These are not purely cosmetic — dialogue choices may have minor mechanical effects (small rent negotiation, lease term adjustment, reputation impact). Primarily narrative and tonal. They make the mall feel inhabited by specific, memorable people.

---

## Level Progression

### Structure
Each level is a fresh mall. Nothing carries forward except the player's score total and unlocked capabilities.

Levels escalate in starting complexity:

| Level | Mall Type | Anchor Slots | Store Slots | Starting Occupancy | Bottom Line Pressure |
|-------|-----------|--------------|-------------|-------------------|---------------------|
| 1 | Strip mall / small enclosed | 1 | ~20 | 95% | Low |
| 2 | Mid-size single floor | 2 | ~40 | 95% | Medium |
| 3 | Regional mall, 2 floors | 4 | ~80 | 95% | High |
| 4+ | Large regional, multiple wings | 6+ | 120+ | 95% | Very High |

### Score Thresholds
Each level has a score target. Hit it and the next level unlocks. Fail (bankruptcy or forced acquisition) and you replay the level.

### Wing Navigation
Large malls are navigated by wing. A macro view shows the full mall — vacancy heatmap, foot traffic density, closure risk indicators. Tap a wing to enter it. Performance is preserved by not rendering the full mall simultaneously.

---

## Player Capabilities (Unlock Progression)

Not everything is available from the start. Capabilities unlock as the player progresses through levels or hits score milestones.

| Capability | Available From | Notes |
|-----------|---------------|-------|
| View visitor thoughts | Level 1 | Core mechanic, always on |
| Place/remove decorations | Level 1 | Core mechanic |
| Cancel leases (with penalty) | Level 1 | Nuclear option |
| Lease non-renewal | Level 1 | Standard exit |
| Accept/decline tenant offers | Level 1 | Core mechanic |
| Speed toggle (1x/2x/3x) | Level 1 | QoL |
| Wing macro view | Level 2+ | Navigation for large malls |
| Tenant negotiation | Level 2+ | Minor rent or term adjustments |
| Cutaway dialogue | Triggered by tenant type | Narrative layer |
| Bribe / regulatory response | Level 2+ | Event response option |
| Developer offer negotiation | Level 3+ | Counter-offer mechanic |

---

## What the Player Is NOT Doing (By Default)

As important as what they are doing:

- **Not building.** The mall already exists. You inherited it.
- **Not saving it.** That's not the game. The mall dies. The question is how beautifully and how slowly.

### Desperation Tools (available but costly to score)
Some actions are available as emergency levers when the bottom line is critical. Using them is an admission that pure decline management has failed — they buy survival at the cost of score.

- **Marketing / promotions** — foot traffic spike for 1-2 months. Score multiplier temporarily reduced. The right move when you're about to hit the debt ceiling and need visitors NOW regardless of cost to score.
- **Renovation** — updates a section of the mall, temporarily boosting tenant viability and foot traffic. Destroys the aesthetics multiplier for that area permanently. Irreversible. A genuine last resort.

The player can use these tools. They should feel like defeat when they do.

---

## Build Strategy

Skip the webapp prototype. The core question — does the tension mechanic feel good — is a game feel question that only answers in native rendering. A webapp tycoon prototype is a spreadsheet with a UI.

**Phase 1 target:** SpriteKit directly. Placeholder rectangles for storefronts, dots for visitors, numbers on screen. No art. One question only: does watching vacancy go up while the bank account goes down feel tense and satisfying?

That's answerable in a weekend without a webapp in between.

---

*Draft v0.3 — Trevor's notes incorporated*
*Next: lock down numbers, then Phase 1 prototype*
