# BGM Track Generation Guide — Suno

Reference this while generating tracks for the BGM pool. Read `features/bgm_system.md` and `features/bgm_tagging_guide.md` first.

## Goal

Generate 24–28 discrete music tracks across three tiers (Island Commons, Location-Leaning, Exclusive Moments), plus seasonal/weather variants for a subset. Each track is a standalone piece selected by weighted probability — they do not layer or play simultaneously.

## Ground Rules

1. **Lock a key family.** All tracks should be in compatible keys: C major, A minor, F major, or G major. Mixing freely within this family keeps transitions smooth when one track follows another.

2. **Lock a BPM range.** Stay within 65–80 BPM across the pool. Tracks at the extremes (65 vs. 80) will feel noticeably different in energy, so use the range intentionally — slower for night/winter/early-progress, faster for afternoon/summer/gathering.

3. **Use Instrumental mode.** Toggle "Instrumental" on so Suno doesn't generate vocals.

4. **Target 45–90 seconds per track.** Long enough to establish mood, short enough that the pool rotates through tracks during a play session. Suno generates 1–2 minutes by default — trim to a clean loop point later.

5. **Generate in batches by tier.** Do all Island Commons first so they form a cohesive family. Then Location-Leaning. Then Exclusive Moments. This keeps the pool's identity consistent.

6. **Generate 3–4 candidates per slot.** Suno is unpredictable. Keep the one that fits best with the rest of the pool. Discard generously.

## Tier 1 — Island Commons (8–10 tracks)

These define the island's baseline sound. They should all feel like they belong to the same place and could follow each other without jarring transitions.

Generate in three mood groups:

### Still / Contemplative (3–4 tracks)

For early progress, night, winter. The island at its emptiest and quietest.

**Style of Music:**
```
ambient piano, minimal, contemplative, slow, sparse, soft reverb, 68 BPM, C major
```

**Description variations (pick one per generation):**
```
A. A single piano playing very slowly in an empty room. Long pauses between
   phrases. Feels like early morning before anyone is awake. No accompaniment.

B. Gentle sustained tones with one or two piano notes placed carefully. More
   silence than sound. Like fog sitting on still water.

C. A quiet piano piece that sounds like remembering something. Unhurried,
   spacious, slightly melancholic but not sad. Winter stillness.
```

### Warm / Wandering (3–4 tracks)

For mid-progress, afternoon, summer/autumn. The island coming alive.

**Style of Music:**
```
gentle piano, warm, wandering melody, calm exploration, soft acoustic, 74 BPM, G major
```

**Description variations:**
```
A. A piano piece that feels like walking through a sunlit neighborhood. Gentle
   melody that meanders without urgency. Warm, open, curious.

B. Soft piano with a hint of acoustic guitar or strings underneath. Feels like
   an afternoon in a quiet coastal town. Comfortable and unhurried.

C. A calm piano melody with gentle forward motion. Not arriving anywhere
   specific, just enjoying the walk. Golden light, autumn warmth.
```

### Gently Hopeful (2–3 tracks)

For performed/resonant progress, morning, spring. The island after restoration.

**Style of Music:**
```
piano, hopeful, gentle resolution, warm, uplifting calm, soft strings, 76 BPM, F major
```

**Description variations:**
```
A. A piano melody that feels like good news arriving quietly. Not triumphant,
   just warmly certain. The feeling after something lost has been found.

B. Gentle piano with soft strings. Feels like the first warm morning of spring.
   Something has changed for the better and the island knows it.

C. A simple, clear piano phrase that feels like completion. Not an ending —
   more like the island settling into a version of itself it always wanted.
```

## Tier 2 — Location-Leaning (6–8 tracks)

Each track should evoke the spatial character of one or two landmarks. Use more specific textural descriptions.

### Ferry Plaza (1–2 tracks)

**Style of Music:**
```
piano, open air, harbor, gentle bustle, warm social, sea breeze, 74 BPM, C major
```

**Description:**
```
A piano piece that feels like standing at an open harbor. Spacious, with a
sense of arrival or departure. Slightly more social and bright than the
commons tracks. The sound of a gathering place that's calm but not empty.
```

### Trinity Church (1–2 tracks)

**Style of Music:**
```
piano, bell-like tones, reverberant, sacred space, enclosed, reflective, 70 BPM, A minor
```

**Description:**
```
A piano piece that sounds like it's being played inside a stone church.
Bell-like upper register notes with natural reverb. Reflective, slightly
sacred. The space between notes matters as much as the notes themselves.
```

### Tunnels — Bi Shan / Long Shan (1–2 tracks)

**Style of Music:**
```
piano, deep reverb, echo, underground, mysterious, intimate, 66 BPM, A minor
```

**Description:**
```
A piano piece that feels like being underground. Deep reverb, notes that
linger and overlap. Intimate but spacious — the contradiction of a tunnel.
Slightly mysterious but not frightening. The sound of walking with someone
through the dark.
```

### Bagua Tower (1–2 tracks)

**Style of Music:**
```
piano, ascending, high register, airy, elevated, expansive, open sky, 72 BPM, G major
```

**Description:**
```
A piano piece that uses the upper register. Feels like height and open air.
Ascending phrases, bright but not loud. The feeling of seeing the whole
island from above. Clear, expansive, synthesizing.
```

## Tier 3 — Exclusive Moments (4–6 condition-gated + up to 4 landmark-specific)

These are special. Each plays only under specific conditions and should feel noticeably distinct from the commons and location tracks.

### Dawn Harbor

**Condition:** ferry plaza + morning only

**Style of Music:**
```
solo piano, dawn, first light, still harbor, tender, beginning, 68 BPM, C major
```

**Description:**
```
The very first sound of the day on a quiet island harbor. A single piano,
completely alone. Tender and still. Feels like the world hasn't quite
started yet. This is the piece the player might hear on their first
morning and never forget.
```

### Island Rain

**Condition:** any location + rain

**Style of Music:**
```
piano, rain, muffled, intimate, rhythmic, gentle percussion, cozy, 70 BPM, A minor
```

**Description:**
```
A piano piece that sounds like it's being played while rain falls outside.
Slightly muffled, intimate, with a gentle rhythmic quality that echoes the
rain. Not melancholic — more like the comfort of being indoors during a
storm. The island's rain voice.
```

### After the Stage

**Condition:** any location + performed or resonant progress

**Style of Music:**
```
piano, resolution, warm, complete, memory, gentle strings, 74 BPM, F major
```

**Description:**
```
A piano piece that sounds like the island after something important happened.
Warm, settled, complete. Has a quality of memory — not nostalgia, but the
quiet confidence of a place that knows its own story now. Gentle strings
underneath.
```

### Resonant Night

**Condition:** any location + night + resonant state

**Style of Music:**
```
solo piano, night, deep calm, resonant, island at rest, 64 BPM, C major
```

**Description:**
```
The rarest piece in the game. A solo piano at night on an island that has
fully remembered itself. Deeply calm, unhurried, with a sense of profound
rest. Not sleepy — more like the satisfaction of a completed journey.
The player may only hear this once.
```

### Restored Landmark (up to 4)

**Condition:** specific landmark + after that landmark's fragment is found

Generate one per landmark, using the Tier 2 location prompt as a starting point but with a warmer, more resolved character — the same space, but it sounds different now that the fragment is home.

## Generating Variants

For 4–5 Island Commons tracks, generate seasonal variants:

**Method:** Use Suno's "Create Similar" or "Extend" feature with the base track as input. Adjust the style prompt:

- **Spring variant:** add `light, airy, new growth, bright` to the style
- **Summer variant:** the base track often already sounds like summer — only generate if distinctly needed
- **Autumn variant:** add `warm, mellow, golden, lower register, softer` to the style
- **Winter variant:** add `sparse, crystalline, still, cold air, minimal` to the style

For 2–3 Location-Leaning tracks, generate weather variants:

- **Rain variant:** add `muffled, intimate, rain rhythm, cozy` to the style
- **Fog variant:** add `distant, soft edges, hazy, reduced clarity` to the style

## Post-Generation Workflow

### Trimming to a clean loop

1. Import each track into Audacity (free) or any audio editor.
2. Find a musically natural loop point — usually at a bar boundary. At 72 BPM, one bar = 3.33 seconds. A good loop is 12 bars (40s) or 16 bars (53s).
3. Apply a very short crossfade (5–20ms) at the loop boundary to avoid clicks.
4. Record the exact trimmed duration in seconds — you'll need this for the `duration` field in `bgm_catalog.gd`.
5. Export as OGG Vorbis, quality 6 (good balance of size and fidelity).
6. Normalize loudness to ~-14 LUFS so all tracks in the pool have consistent perceived volume.

### File naming and storage

Place all BGM pool files in `resources/audio/music/bgm/`:

```
resources/audio/music/bgm/bgm_[descriptive_name].ogg
resources/audio/music/bgm/bgm_[descriptive_name]_[variant_type].ogg
```

### Pool coherence test

After generating a batch, play 5–6 tracks in random order with 5–10 second silence gaps between them. This simulates the in-game experience. Ask:

- Do they feel like the same island?
- Does any track stick out as "wrong game"?
- Are the transitions between tracks comfortable or jarring?

Cut anything that breaks the family feel. Coherence across the pool matters more than any individual track being interesting.

### Tagging

After accepting a track into the pool, tag it using the workflow in `features/bgm_tagging_guide.md`. Listen once, note your instinct for location/time/mood, then fill in the five weight groups.

## Landmark Motifs (separate from BGM pool)

These are short one-shot clips, not looping tracks. They play when the player enters a landmark trigger zone.

| Fragment | Suno style prompt | Feel |
|---|---|---|
| `church_bells` | `solo piano, bell-like, reverberant, 3 notes, sacred, C major` | Clear, ringing, upward |
| `bi_shan_echo` | `solo piano, echo, reverb tail, mysterious, 4 notes, A minor` | Hollow, reflective, lingering |
| `long_shan_route` | `solo piano, walking pace, warm, companion feel, 4 notes, C major` | Steady, reassuring, paired |
| `tower_chamber` | `solo piano, ascending, height, resolution, 5 notes, G major` | Rising, open, arriving |

Generate with Suno, trim to just the phrase (3–8 seconds), add a reverb tail fade-out, and export as OGG.

```
resources/audio/music/motifs/motif_church_bells.ogg
resources/audio/music/motifs/motif_bi_shan_echo.ogg
resources/audio/music/motifs/motif_long_shan_route.ogg
resources/audio/music/motifs/motif_tower_chamber.ogg
```
