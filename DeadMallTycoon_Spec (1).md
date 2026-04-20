# Dead Mall Tycoon
## Pre-Development Concept Document
*RIG Tech LLC — April 2026*

---

## Concept

You are not saving the mall. You are managing its death.

Dead Mall Tycoon is a tycoon/simulation game where the objective is inverted — instead of building a thriving commercial center, you are presiding over the slow, dignified, or chaotic decline of an American shopping mall. The longer you keep it alive on the absolute minimum viable number of tenants, the higher your score. You are rewarded for teetering on the edge of closure without letting it tip over.

The emotional core is nostalgia and liminality. Visitors wander the corridors alone, their thought bubbles surfacing memories of what this place used to be. The mall remembers itself even as it forgets how to survive.

---

## The Core Tension

**Fewer stores = higher score per day survived.**
**Fewer stores = higher closure risk.**

This creates a genuine strategic dilemma on every decision. The optimal play is to keep the mall on minimum viable life support for as long as possible — one nail salon, one cell phone kiosk, one pretzel stand — milking every day of survival while the clock ticks toward inevitable closure.

Every tenant decision is a calculated risk:
- Accept the vape shop? Fills a slot, slows the score multiplier, buys time.
- Let the anchor tenant leave? Score spikes, but closure risk spikes with it.
- Hold on to the arcade? Traffic is good for the bottom line, terrible for the dead mall aesthetic score.

---

## Scoring System

### Score Formula
```
Score = (Years Survived × Empty Store Slots) × Aesthetics Multiplier
```

**Years Survived** — total time the mall has remained open, measured in in-game years.

**Empty Store Slots** — the number of vacant storefronts. More vacancies = higher multiplier. A mall with 2 tenants in 40 slots scores dramatically higher per year than one with 20 tenants.

**Aesthetics Multiplier** — a rating based on the presence and condition of liminal architectural features. See Aesthetics System below.

### Foot Traffic Floor
Visitors are required but unwanted. Drop below a minimum foot traffic threshold and closure risk accelerates dramatically. The uncanny wrongness of a liminal space is *almost* empty, not completely empty. Someone has to be there to remember.

Optimal play keeps foot traffic just above the floor — enough to sustain the fiction that the mall is still open, not enough to feel like it's thriving.

### Score is separate from money
Score tracks your legacy. Money tracks your survival. You can be scoring beautifully and hemorrhaging cash simultaneously. Both matter.

---

## Money System

### The Bottom Line
Every mall has monthly operating costs — utilities, maintenance, security, property taxes. These do not scale down with vacancy. A nearly empty mall costs almost as much to operate as a full one. This is historically accurate and mechanically brutal.

### Tenant Revenue
Each tenant pays monthly rent. Revenue must cover the bottom line. Fall short and you go into debt.

### Debt and Bankruptcy
You are allowed to carry a specific amount of debt before the mall is declared bankrupt and the session ends — either via forced closure or redevelopment. The debt ceiling is a buffer, not a safety net.

### Tenant Financial Health
Individual tenants have their own financial health. If a store is not receiving enough foot traffic to sustain their business model, they will close — which simultaneously opens a slot (good for score) and removes revenue (bad for the bottom line).

**Tenant tiers by business model:**
- **High value, low traffic** — luxury goods, specialty medical, law office, financial services. Best for score, good for survival. Rare and hard to attract.
- **Mid value, moderate traffic** — nail salon, cell phone kiosk, discount clothing, tax prep. The workhorses. Most of your tenants will be these.
- **Low value, high traffic** — arcade, food court anchor, dollar store. Bad for score, essential for the bottom line in early game. A necessary evil.
- **Chaos tenants** — Spirit Halloween (seasonal, appears in October, vanishes), pop-up shops, MLM booths, flea market operators. Unpredictable revenue, unpredictable traffic, but deeply authentic to the dead mall experience.

### Anchor Tenants
Anchors are treated as their own category. They are large, drive significant foot traffic, generate substantial revenue, and their departure is a seismic event. Losing an anchor is almost always the beginning of the end — historically accurate.

Anchor departure triggers:
- Immediate revenue loss
- Foot traffic drop (other tenants may follow)
- Closure risk spike
- Potential for a score boost if managed correctly

---

## Aesthetics System

The Aesthetics Multiplier rewards the physical character of a dead mall. Certain architectural and decorative features are associated with the golden age of American mall culture — their presence, and especially their state of decay, increases your multiplier.

### Aesthetic Features (examples)
- **Kugel ball** — the large granite sphere floating on water. Iconic. High multiplier. Expensive to maintain; letting it stop spinning reduces multiplier but saves money.
- **Neon signage** — flickering neon from closed stores left in place. The flicker itself increases the multiplier.
- **Marble flooring** — original 1980s/90s terrazzo or marble. Cracking and staining increases the multiplier.
- **Skylight atrium** — natural light through a deteriorating skylight. Broken panes increase the multiplier.
- **Indoor water fountain** — pennies still on the bottom. Non-functional fountain increases the multiplier more than a functional one.
- **Art installations** — mall art from the original build. The more dated and ignored, the better.
- **Food court seating** — original molded plastic chairs, faded. Still there despite the restaurants being gone.
- **Directory board** — backlit store map with outdated tenant listings. Cannot be updated without losing the multiplier.

### Decay State
Features have condition states: Pristine → Worn → Damaged → Deteriorating → Ruin. Higher decay = higher multiplier, but some features will eventually become safety hazards requiring repair or removal. This creates a maintenance dilemma: fixing something keeps it from becoming a liability but costs multiplier points.

---

## The Visitor System

Visitors are the soul of the game. They are simple agents — they enter, wander, think, leave. Their movement is not complex. Their thoughts are.

### Thought Bubbles
Each visitor generates contextual thought bubbles based on:
- Their visitor profile (age cohort, how many years they've been coming)
- The mall's history (what stores used to occupy each storefront)
- The current state of the space (what's open, what's closed, decay level)
- Specific architectural features they pass

Thoughts are procedurally generated and historically specific. Not "I miss this place" — but "They used to have a KB Toys right here. I saved up for three months to buy a Nintendo 64."

Older visitors (60s+) remember the opening years, the anchor stores, the Christmas displays. Middle-aged visitors (30s-50s) remember the teenage years, the food court rituals, the specific stores that defined their adolescence. Younger visitors (teens-20s) remember the decline — the empty wings, the weird kiosks, the sad Christmas seasons.

### Thought Database
A curated database of real mall archetypes powers the system:
- The kugel ball you could never stop spinning
- The Waldenbooks where you bought your first Stephen King
- KB Toys on Christmas Eve
- The food court pizza place with the specific crust
- The arcade cabinet that was always broken but you played anyway
- The airbrushed t-shirt kiosk
- The specific warm patch of carpet under the skylight
- Orange Julius. Sbarro. Auntie Anne's. Wet Seal. Afterthoughts.

An LLM generates contextually appropriate variations on these archetypes, personalized to the visitor profile and the mall's specific history. This is the AI moat — the same philosophy as DrawEvolve. AI generates the emotional content, not the game mechanics.

---

## Progression System

### Levels = Escalating Starting Conditions
Each level presents a more complex and initially successful mall to kill. You carry nothing forward — each level is a fresh session with a higher baseline challenge.

- **Level 1** — Small single-story strip mall. 1 anchor slot, ~20 store slots. Easy closure risk baseline.
- **Level 2** — Mid-size single-floor enclosed mall. 2 anchor slots, ~40 store slots.
- **Level 3** — Two-floor regional mall. 4 anchor slots, ~80 store slots, food court, atrium.
- **Level 4+** — Larger configurations, multiple wings, more complex bottom line requirements.

### Level Unlock
Achieving a target score on the current level unlocks the next. Higher levels start with more tenants, more anchors, and therefore require more sophisticated decline management to achieve the empty-store multipliers that drive high scores.

### Wing Navigation
To preserve performance, large malls are navigated by wing. A toggle lets you view individual wings or a macro overview of the full mall layout. You are not rendering the entire mall simultaneously.

The macro view shows: overall vacancy percentage, foot traffic heatmap by wing, closure risk indicators, and visitor density.

---

## Random Events

Events introduce chaos and narrative into each session. They are not avoidable — they are the story of a mall dying.

### Negative Events
- **Anchor departure announcement** — 90-day notice before an anchor leaves. You have time to prepare or scramble.
- **Roof leak** — maintenance cost spike. Ignore it and the affected wing's aesthetics deteriorate faster.
- **Health inspection** — food court tenant at risk. Bribe, close, or fix.
- **Structural report** — part of the building requires repair or closure. Expensive.
- **Economic downturn** — foot traffic drops across the board for a season.

### Positive Events (for the mall, complicated for the score)
- **Viral nostalgia post** — a Reddit post or TikTok surfaces a memory of the mall. Foot traffic spikes temporarily. Bad for score, good for the bottom line, genuinely bittersweet.
- **Urbex YouTuber** — films the empty corridors. Brings a weird crowd. Doesn't spend money. Does bring attention.
- **Local news segment** — "Whatever happened to..." piece. More foot traffic, more visibility, more pressure from the city.
- **Ghost tour operator** — wants to run overnight events. Revenue opportunity with a complex tradeoff.
- **Christmas pop-up season** — seasonal vendors appear, revenue spikes, but occupancy temporarily rises and score multiplier drops.

### Tenant Opportunity Events
New prospective tenants appear periodically. You choose whether to accept them. Every acceptance is a deliberate trade: revenue vs. score multiplier, stability vs. authenticity.

---

## Visual and Aesthetic Direction

### Era: Late 1980s — Early 1990s commercial optimism. Frozen. Fading.

The mall was designed to be the center of everything. The architecture said permanence. The signage said prosperity. The terrazzo floors said this will always be here.

It is not always here anymore.

Visual references:
- Actual dead mall photography (Seph Lawless, r/deadmalls)
- The specific color palette of that era — mauve, teal, cream, brass fixtures
- Fluorescent lighting, some tubes out
- The way carpet looks when it's been there for 35 years
- Water stains on drop ceilings
- Handwritten "STORE CLOSING — EVERYTHING MUST GO" signs

### RCT-style isometric or 2.5D
Player sees the mall from above at an angle. Visitors are small figures wandering the corridors. Thought bubbles appear above them in clean, readable type.

The visual language is slightly stylized — not photo-realistic, but not cartoonish. Think the warm nostalgia of a memory rather than the sharpness of a photograph.

---

## Build Strategy

### Phase 1: Proof of Concept (2-3 focused sessions)
- Core tension mechanic: store count vs. closure risk vs. score
- Basic money system: bottom line, tenant rent, debt ceiling
- One mall layout (Level 1)
- Tenant acceptance/rejection system
- Session end state (bankruptcy or voluntary close)
- No visitors yet. No aesthetics system. Pure numbers.

**Goal: Is the core loop fun?** Can you feel the tension of keeping one tenant alive while watching the score climb?

### Phase 2: The Soul (3-4 sessions)
- Visitor agents with basic pathfinding
- Thought bubble system with curated database
- LLM integration for procedural thought generation
- Basic aesthetics features (3-4 landmark items)
- Decay states

**Goal: Does it feel like a dead mall?** Are the thought bubbles landing?

### Phase 3: Progression and Events (3-4 sessions)
- Level 2 and 3 mall layouts
- Wing navigation system
- Random event system (5-6 events)
- Tenant opportunity events
- Score unlock thresholds

### Phase 4: Polish (ongoing)
- Full thought bubble database
- Sound design (distant muzak, footsteps on terrazzo, flickering fluorescents)
- Visual decay system fully implemented
- Additional aesthetic features
- Balancing

---

## Tech Stack (Proposed)

- **Platform**: iOS (iPad primary, iPhone secondary)
- **Engine**: SpriteKit or Unity (TBD based on isometric complexity)
- **AI integration**: LLM API for thought bubble generation, context-aware per visitor profile and mall state
- **Storage**: Local persistence for session state, high scores
- **Backend**: Lightweight — similar to DrawEvolve's Cloudflare Worker approach for LLM calls

---

## What Makes This Different

Every tycoon game is about growth. This one is about loss. The inversion is the game.

The thought bubble system powered by contextual AI is the moat. Nobody else is doing procedurally generated emotional memory in a game. The feelings are real — everyone has a mall memory. The game gives those memories a place to live as the mall dies.

The target user is anyone who grew up going to a mall and felt the specific sadness of watching it empty out. That is tens of millions of people.

---

## Open Questions

- Engine choice: SpriteKit (native iOS, familiar territory) vs Unity (more isometric tooling)
- Thought bubble generation: fully LLM at runtime vs. large curated database with LLM as fallback
- Monetization: premium ($2.99-$4.99 one-time) vs. freemium with level unlocks
- Name: Dead Mall Tycoon is descriptive and searchable. Is there something more evocative?
- Sound: licensed 80s/90s elevator music (complicated) vs. original score in that style (cleaner)

---

*Document version 0.1 — concept stage. Everything subject to change.*
*Next step: prototype Phase 1 core loop.*
