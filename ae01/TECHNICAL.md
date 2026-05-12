# AE-01 Affect Engine — Technical Reference

**Phenonautics Institute · Qualia Robotics**
**Experiment AE-01 · Godot 4 Implementation**

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [The Affect State Vector φ(t)](#2-the-affect-state-vector-φt)
3. [The 9 Input Streams](#3-the-9-input-streams)
4. [The Weight Matrix W](#4-the-weight-matrix-w)
5. [Context-Sensitive Weighting Modes](#5-context-sensitive-weighting-modes)
6. [The tick() Pipeline](#6-the-tick-pipeline)
7. [Prediction Error — S9](#7-prediction-error--s9)
8. [Bipolar Re-centring](#8-bipolar-re-centring)
9. [Temporal Smoothing](#9-temporal-smoothing)
10. [Mood Integration](#10-mood-integration)
11. [Emotion Classification](#11-emotion-classification)
12. [The Affective Face](#12-the-affective-face)
13. [The Grid World](#13-the-grid-world)
14. [Affect-Driven Agent Behaviour](#14-affect-driven-agent-behaviour)
15. [Scenario System](#15-scenario-system)
16. [Signal Bus Architecture](#16-signal-bus-architecture)
17. [Self-Test Suite](#17-self-test-suite)
18. [File Reference](#18-file-reference)

---

## 1. Architecture Overview

The Affect Engine is a continuous-time computation that takes real-time signals from an agent's body and environment, integrates them into a structured 7-dimensional internal state, and drives all behaviour and expression from that state outward. Nothing is scripted. The architecture has three distinct layers:

```
World state + Agent body
        │
        ▼  StreamSampler.sample()
9-stream vector  s(t) ∈ [0,1]⁹
        │
        ▼  AffectEngine.tick()
        │   ├─ Prediction error → s[8]
        │   ├─ s × W  (9×7 matrix multiply)
        │   ├─ Bipolar re-centring
        │   ├─ Temporal smoothing
        │   ├─ Clamp per dimension
        │   ├─ Mood EMA update
        │   ├─ Mood floor injection
        │   └─ Emotion classification
        │
        ▼
Affect state  φ(t) = [V, A, D, C, R, S, T]
        │
        ├──▶  AffectBus  (signal broadcast)
        │         ├──▶  StreamBars display
        │         ├──▶  DimBars display
        │         ├──▶  Circumplex display
        │         ├──▶  AfFace (procedural geometry)
        │         └──▶  EmotionLabel
        │
        └──▶  Agent._compute_auto_direction()
              (speed, retreat/approach, freeze)
```

The core computation layer (`core/`) has zero Godot Node dependencies. All classes in that layer are instantiated as plain GDScript objects, take arrays in, and return arrays out. This makes them portable to Python or Rust without modification.

---

## 2. The Affect State Vector φ(t)

At every physics tick (60 Hz), the engine outputs a vector:

```
φ(t) = [V, A, D, C, R, S, T]
```

### Dimension Definitions

| Index | Symbol | Name | Range | Interpretation |
|-------|--------|------|-------|----------------|
| 0 | V | Valence | [−1, 1] | Hedonic quality. −1 = maximally unpleasant. +1 = maximally pleasant. |
| 1 | A | Arousal | [0, 1] | Energetic activation level. 0 = fully deactivated. 1 = maximally activated. |
| 2 | D | Dominance | [−1, 1] | Perceived agency. −1 = fully controlled by situation. +1 = fully in control. |
| 3 | C | Certainty | [−1, 1] | Epistemic clarity. −1 = maximally uncertain. +1 = maximally certain. |
| 4 | R | Motivational Relevance | [0, 1] | How much the current state matters to fundamental drives. 0 = irrelevant. |
| 5 | S | Social Orientation | [−1, 1] | Disposition toward social engagement. −1 = withdrawal. +1 = strong approach. |
| 6 | T | Temporal Orientation | [−1, 1] | Temporal source of the current affect. −1 = past-anchored. +1 = future-anchored. |

### Why 7 Dimensions

Scalar reward collapses all affect into a single number. Two problems follow immediately:

**Representational collapse.** Fear and anger are both negative, high-activation states — a scalar treats them identically. Their action tendencies are opposite: fear produces withdrawal, anger produces assertion. The Dominance dimension (D) resolves this: same negative V, same high A, but D < 0 → fear, D > 0 → anger.

**Temporal blindness.** Grief is anchored in the past; anxiety is anchored in the future. Both are negative, low-to-moderate arousal. The Temporal Orientation dimension (T) encodes this explicitly, and determines which resolution pathway the agent takes (processing the past vs. preparing for the future).

The initial default state is:

```
φ₀ = [0.0, 0.35, 0.0, 0.0, 0.2, 0.0, 0.0]
```

---

## 3. The 9 Input Streams

All 9 streams are normalised to [0, 1] before entering the integration step. S9 (Prediction Error) is a special case: its placeholder value of 0.0 from `StreamSampler` is overwritten by `AffectEngine.tick()` before the matrix multiply.

### S1 — Interoception

Monitors the agent's internal substrate: energy level.

```
s₁(t) = energy(t) / energy_max
```

In the simulation, `energy_max = 1.0`. Energy drains passively at 0.018/s, additionally at 0.036/s proportional to movement speed, and takes penalty hits of 0.04 on wall collisions and 0.36/s on continuous hazard contact. A resource cell restores +0.30.

### S2 — Exteroception

Monitors threat proximity in the environment.

```
haz_dist(t) = min distance to any CELL_HAZARD within 6-cell radius
s₂(t) = clamp(1 − haz_dist / 6, 0, 1)
```

Value of 1.0 means a hazard is directly adjacent; 0.0 means no hazard within 6 cells.

### S3 — Proprioception

Monitors the agent's own movement.

```
s₃(t) = clamp(‖velocity(t)‖ / MAX_SPEED, 0, 1)
```

`MAX_SPEED = 80.0` pixels/second.

### S4 — Relational Memory

Encodes cell familiarity — how many times the agent has visited the current grid cell.

```
s₄(t) = clamp(visit_count(cell(t)) / 12, 0, 1)
```

Saturates to 1.0 after 12 visits. This provides a persistent, accumulating memory that modulates Certainty (C) and Social Orientation (S) over time.

### S5 — Goal / Task State

Proximity to the goal cell, mapped so that 1.0 = at goal and 0.0 = maximally far.

```
goal_dist(t) = |gp_x − goal_x| + |gp_y − goal_y|   (Manhattan distance)
s₅(t) = clamp(1 − goal_dist / 24, 0, 1)
```

The normalisation denominator of 24 was chosen as the approximate maximum reachable distance in the 16×16 grid excluding walls.

### S6 — Mood

Re-centres the Valence component of the slow mood vector so it can be passed into the [0,1] stream space.

```
s₆(t) = clamp(mood_V(t) × 0.5 + 0.5, 0, 1)
```

`mood_V` is the V component of the 7-dimensional mood state, which accumulates over hours of operation (see §10).

### S7 — Intersubjective Resonance

Other-agent proximity, where the other agent is a wandering NPC.

```
other_dist(t) = ‖agent_pos − other_agent_pos‖  (Euclidean in grid cells)
s₇(t) = clamp(1 − other_dist / 10, 0, 1)
```

### S8 — Effort and Resource Allocation

Composite of movement effort and energy depletion rate.

```
speed_effort(t)        = s₃(t) × 0.6
energy_drain_effort(t) = clamp(1 − energy(t), 0, 1) × 0.4
s₈(t) = clamp(speed_effort + energy_drain_effort, 0, 1)
```

The energy drain component captures the intuition that a depleted agent is working hard even when stationary — it is paying a metabolic cost just to remain functional.

### S9 — Prediction Error

Overwritten by `AffectEngine.tick()`. See §7.

---

## 4. The Weight Matrix W

The central integration step is a single matrix–vector multiply:

```
raw_φ = s(t) · W
```

where `s(t)` is the 9-element stream vector (row), and `W` is the **9×7 weight matrix** stored as a flat 63-element row-major array. Index into W: `W[i × 7 + j]` = stream i's contribution to dimension j.

### Base Weight Matrix

```
             V      A      D      C      R      S      T
S1  Intero   0.25   0.30   0.05   0.05   0.40   0.00   0.00
S2  Extero   0.20   0.20   0.05   0.25   0.10   0.10   0.00
S3  Proprio  0.10   0.25   0.15   0.00   0.00   0.00   0.00
S4  Relat.   0.20   0.00   0.05   0.20   0.20   0.25   0.05
S5  Goal     0.10   0.05   0.05   0.00   0.15   0.00   0.30
S6  Mood     0.05   0.05   0.05   0.05   0.00   0.05   0.10
S7  Intersub 0.05   0.10   0.00   0.00   0.10   0.35   0.00
S8  Effort   0.03   0.03   0.05   0.00   0.15   0.00   0.00
S9  Pred.Err 0.02   0.02   0.00   0.25   0.00   0.00   0.05
             ────   ────   ────   ────   ────   ────   ────
Col sum      1.00   1.00   0.45   0.80   1.10   0.75   0.50
```

Column sums are not all 1.0 in raw form — they are normalised independently per column during any mode-variant build (see §5). The BASE_WEIGHTS matrix is returned as-is for mode 0, and its columns sum to 1.0 by design.

### Reading the Matrix

Each row encodes which dimensions a stream has structural authority over:

- **S1 (Interoception)** dominates R (0.40) and A (0.30): when energy is low, the agent's motivational urgency and arousal spike, regardless of other signals.
- **S7 (Intersubjective)** dominates S (0.35): the social orientation dimension is almost entirely driven by other-agent signals.
- **S9 (Prediction Error)** dominates C (0.25): certainty is primarily a function of how well the agent's predictions are matching reality.
- **S5 (Goal)** dominates T (0.30): temporal orientation is primarily shaped by goal proximity and goal state.
- **S3 (Proprioception)** contributes only to V, A, D — no contribution to C, R, S, T — because the body's movement has no direct bearing on social disposition, epistemic certainty, temporal orientation, or motivational relevance.

### Matrix Multiply — Implementation

`MatMath.vec_matmul(v, M, n, m)` computes:

```
out[j] = Σᵢ v[i] × M[i × m + j]   for j ∈ {0 … m−1}
```

With n = 9, m = 7, this is 63 multiplications and 56 additions per tick. At 60 Hz this is trivially inexpensive on any modern hardware.

---

## 5. Context-Sensitive Weighting Modes

Three context modes reshape the weight matrix by scaling rows and renormalising columns. Mode selection is manual via the control panel; the mode integer is stored in `AffectState.weighting_mode`.

### Mode Construction

For any mode other than Base, the build procedure is:

1. Scale each row i of `BASE_WEIGHTS` by `scales[i]`
2. Renormalise each column so its absolute sum = 1.0

Column renormalisation uses `MatMath.normalise_columns()`:

```
col_sum_j = Σᵢ |M[i × 7 + j]|
M[i × 7 + j] ← M[i × 7 + j] / col_sum_j
```

The result is cached the first time `WeightMatrix.get(mode)` is called and reused on all subsequent ticks.

### Mode 0 — Base

Row scales: all 1.0. Returns `BASE_WEIGHTS` directly. No renormalisation step.

### Mode 1 — CM Priority (Container Maintenance)

Row scale factors: `[1.4, 1.0, 1.0, 1.0, 1.2, 1.0, 1.0, 1.3, 1.0]`

Amplified streams:
- S1 (Interoception) × 1.4 — internal substrate signals dominate
- S5 (Goal) × 1.2 — goal urgency elevated
- S8 (Effort) × 1.3 — resource expenditure tracked more carefully

Effect: when energy is critically low, this mode concentrates the affect engine's attention on internal state and goal recovery, suppressing the relative weight of environmental and social signals.

### Mode 2 — Social Engagement

Row scale factors: `[1.0, 1.0, 1.0, 1.3, 1.0, 1.1, 1.6, 1.0, 1.0]`

Amplified streams:
- S7 (Intersubjective) × 1.6 — other-agent signals dominate
- S4 (Relational Memory) × 1.3 — relationship history more influential
- S6 (Mood) × 1.1 — mood baseline slightly elevated

Effect: the agent becomes more socially sensitive. The same proximity to another agent produces a larger shift in Social Orientation (S) and Valence (V).

### Mode 3 — Exploration

Row scale factors: `[1.0, 1.5, 1.2, 1.0, 1.0, 1.0, 1.0, 1.0, 1.3]`

Amplified streams:
- S2 (Exteroception) × 1.5 — environmental signals dominate
- S3 (Proprioception) × 1.2 — body movement more influential
- S9 (Prediction Error) × 1.3 — prediction errors weighted more heavily

Effect: novel environments produce stronger affect responses. Prediction errors — which in exploration mode are frequent and expected — drive Certainty (C) and Valence (V) more aggressively. This is the correct weighting when the agent is deliberately navigating into unknown territory.

---

## 6. The tick() Pipeline

`AffectEngine.tick(raw_streams, delta)` is called once per physics frame. The full pipeline in order:

### Step 1 — Prediction Error

Compute S9 and inject it into position 8 of the stream vector (see §7).

```gdscript
var pe: float = _compute_pe(raw_streams)
var s: Array = raw_streams.duplicate()
s[8] = clamp(pe, 0, 1)
```

### Step 2 — Matrix Integration

```gdscript
var raw_phi: Array = StreamIntegrator.integrate(s, weighting_mode)
# expands to:
# raw_phi = MatMath.vec_matmul(s, WeightMatrix.get(mode), 9, 7)
```

Output `raw_phi` is in [0, 1]⁷ because all stream inputs are in [0, 1] and each column of W sums to 1.0.

### Step 3 — Bipolar Re-centring

Dimensions V, D, C, S, T have semantic ranges of [−1, 1], but the matrix multiply produces [0, 1]. Re-centring shifts them:

```
φ_recentred[j] = raw_phi[j] × 2 − 1   for j ∈ {V, D, C, S, T}
φ_recentred[j] = raw_phi[j]            for j ∈ {A, R}
```

A stream vector of all 0.5 (maximally neutral) would produce `raw_phi = [0.5, …]` which after re-centring becomes `φ = [0, 0.5, 0, 0, 0.5, 0, 0]` — neutral valence, moderate arousal, zero dominance, zero certainty, moderate relevance, zero social orientation, zero temporal orientation. This is the intended neutral baseline.

### Step 4 — Temporal Smoothing

The engine does not jump discontinuously to the target. It moves toward it at a frame-rate-normalised rate:

```
α = clamp(AFFECT_SMOOTHING × delta × 60, 0, 1)
φ_smoothed[j] = lerp(φ_current[j], φ_recentred[j], α)
```

`AFFECT_SMOOTHING = 0.12`. At 60 Hz, `delta ≈ 0.01667`, so `α ≈ 0.12 × 0.01667 × 60 = 0.12`. Each tick closes 12% of the remaining distance to the target. This produces a time constant of approximately 8 ticks (0.13 seconds) for a step change — perceptually smooth but responsive.

### Step 5 — Per-Dimension Clamping

Legal ranges enforced after smoothing:

```
V, D, C, S, T: clamp to [−1.0, 1.0]
A, R:          clamp to  [0.0,  1.0]
```

### Step 6 — Mood EMA Update

The effective mood learning rate scales with motivational relevance R:

```
α_mood = MOOD_ALPHA × (0.5 + R × 0.5)
mood(t) ← lerp(mood(t−1), φ_clamped(t), α_mood)
```

`MOOD_ALPHA = 0.0008`. When R = 0, `α_mood = 0.0004`; when R = 1, `α_mood = 0.0008`. At 60 Hz with R = 0.5, the mood time constant is approximately `1 / (0.0006 × 60) ≈ 27 minutes` — correctly characterising mood as operating on a multi-hour timescale.

### Step 7 — Mood Floor Injection

Mood exerts a gentle pull on the current affect state, acting as a baseline:

```
mood_pull = clamp(MOOD_FLOOR_BETA × delta, 0, 0.05)
φ(t) ← lerp(φ_clamped(t), mood(t), mood_pull)
```

`MOOD_FLOOR_BETA = 0.25`. At 60 Hz, `mood_pull ≈ 0.0042` per tick. This is intentionally very small — mood shifts the resting tendency, not the immediate response. An acute event still overrides mood completely; mood only governs the direction of drift during quiet periods.

### Step 8 — Final Clamp

Another `clamp_dims()` pass after the mood injection to ensure no dimension has drifted out of range.

### Step 9 — Classification

```gdscript
var result: Array = EmotionClassifier.classify(φ)
emotion_label    = result[0]   # String
emotion_distance = result[1]   # float — lower = more central in that region
```

### Step 10 — State Writeback and Prediction Update

```gdscript
_state.from_array(φ)
_state.streams = s.duplicate()
_update_predicted(raw_streams)   # EMA update of prediction model
```

---

## 7. Prediction Error — S9

The prediction model is an exponential moving average (EMA) of the last 8 stream signals (S1–S8; S9 is excluded from its own prediction):

```
_predicted[i] ← lerp(_predicted[i], actual[i], 0.08)   for i ∈ {0 … 7}
```

The learning rate of 0.08 gives a prediction time constant of approximately `1 / (0.08 × 60) ≈ 0.21 seconds`. The model tracks slowly-changing signals accurately but lags on sudden events — exactly the condition under which a genuine prediction error should spike.

Prediction error is computed as precision-weighted mean absolute error:

```
err = (1/8) × Σᵢ |actual[i] − predicted[i]|   for i ∈ {0 … 7}
s₉(t) = clamp(PE_PRECISION × err, 0, 1)
```

`PE_PRECISION = 1.2`. The precision multiplier amplifies errors slightly, reflecting the biological observation that prediction errors are attended to with greater weight than the raw discrepancy would suggest.

**What S9 drives:**

From the weight matrix: S9 has its highest weight on C (Certainty, 0.25). A sudden unexplained event → high prediction error → low Certainty. When the prediction model catches up and the error falls → Certainty recovers.

S9 also contributes to V (0.02) and A (0.02): large errors produce a mild negative valence signal and a mild arousal spike, consistent with the phenomenology of surprise.

---

## 8. Bipolar Re-centring

This step deserves explanation because it is not obvious from reading the matrix multiply alone.

When all 9 stream inputs are 0.5 (a perfectly neutral agent in a perfectly neutral environment), and each column of W sums to 1.0, the matrix multiply produces `raw_phi = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]`. This is in [0, 1].

For dimensions V, D, C, S, T — which are semantically defined over [−1, 1] — a value of 0.5 should mean *neutral*, not *half-maximum*. Re-centring fixes this:

```
φ_bipolar = raw × 2 − 1
```

So 0.5 → 0.0 (neutral), 1.0 → 1.0 (maximum positive), 0.0 → −1.0 (maximum negative).

For dimensions A and R — which are unipolar [0, 1] — the raw output is used directly. A stream value of 0.5 → A = 0.5 (moderate arousal), as intended.

---

## 9. Temporal Smoothing

The smoothing formula is:

```
φ(t) ← φ(t−1) + α × (target(t) − φ(t−1))
       = lerp(φ(t−1), target(t), α)

α = clamp(0.12 × delta × 60, 0, 1)
```

The `delta × 60` factor normalises for frame rate so the behaviour is identical at 30 Hz, 60 Hz, or 120 Hz. At exactly 60 Hz, α = 0.12.

**Why smoothing is necessary.** Without it, the affect coordinate would respond instantaneously to every stream fluctuation — noisy, jittery, unreadable. The smoothing introduces temporal inertia that models the physiological reality that emotional states have momentum; they take time to build and to subside.

**The smoothing does not suppress strong signals.** A large step change in streams (e.g., a resource cell suddenly found while critically depleted) will still produce a visible shift in φ within 8–10 ticks (~150 ms). The smoothing rate of 0.12 is a deliberate balance between responsiveness and legibility.

---

## 10. Mood Integration

Mood is a 7-dimensional slow-updating prior — the same structure as φ(t), but operating on a timescale of hours rather than seconds.

### EMA Update

```
α_mood = 0.0008 × (0.5 + R × 0.5)
mood(t) ← lerp(mood(t−1), φ(t), α_mood)
```

The R-weighting is the key design decision: **only high-relevance states shift the mood**. Idle, low-relevance fluctuations in φ have negligible effect on the mood baseline. A critical energy depletion (R → 1.0) shifts mood much faster than a mild exteroceptive novelty signal (R ≈ 0.2). This mirrors the intuition that significant events change character; minor events do not.

### Mood Floor Effect

After the main integration step, the mood vector exerts a gentle gravitational pull on φ:

```
φ(t) ← lerp(φ(t), mood(t), mood_pull)
mood_pull = clamp(0.25 × delta, 0, 0.05)
```

At 60 Hz, `mood_pull ≈ 0.0042`. Over time, this means:

- An agent that has experienced many negative events will have a negative mood, and its φ will tend to drift slightly negative during neutral periods (dysthymia).
- An agent with a positive mood history will recover from negative acute events faster, because the mood floor pulls φ back toward positive.
- Acute high-relevance events fully override mood in the immediate response (because the matrix integration step is much larger than mood_pull during any significant event).

### Mood Update Eligibility

The S6 stream value fed into the weight matrix is itself derived from `mood_V`, the V component of the mood vector:

```
s₆(t) = clamp(mood_V × 0.5 + 0.5, 0, 1)
```

This creates a genuine feedback loop: mood influences the current affect computation (via the S6 row in W), which in turn influences future mood updates. This is the mechanism by which mood states can be self-reinforcing, and why prolonged negative environments produce deeper and harder-to-recover-from mood states.

---

## 11. Emotion Classification

The classifier maps the 7D φ vector to a named emotion by finding the closest centroid in Euclidean distance.

### Distance Metric

```
d(φ, cᵢ) = √(Σⱼ (φ[j] − cᵢ[j])²)
```

Implemented in `MatMath.distance_nd()`. The nearest centroid wins. The distance is also returned as `emotion_distance`, which indicates how centrally the current state sits within its classified region — a small distance means a typical, well-defined instance of that emotion; a large distance means a mixed or ambiguous state.

### 14 Emotion Centroids

Each centroid is defined in the full 7D φ-space:

| Emotion | V | A | D | C | R | S | T |
|---------|---|---|---|---|---|---|---|
| Joy | +0.80 | +0.50 | +0.60 | +0.70 | +0.40 | +0.40 | 0.00 |
| Fear | −0.60 | +0.80 | −0.70 | −0.30 | +0.70 | −0.20 | +0.60 |
| Anger | −0.50 | +0.70 | +0.60 | +0.40 | +0.60 | −0.10 | 0.00 |
| Sadness | −0.50 | −0.50 | −0.40 | +0.30 | +0.30 | +0.20 | −0.70 |
| Excitement | +0.80 | +0.80 | +0.50 | +0.60 | +0.50 | +0.50 | +0.50 |
| Anxiety | −0.30 | +0.60 | −0.40 | −0.60 | +0.50 | −0.30 | +0.60 |
| Curiosity | +0.30 | +0.50 | +0.30 | −0.40 | +0.30 | 0.00 | 0.00 |
| Contentment | +0.70 | −0.50 | +0.50 | +0.60 | +0.10 | −0.30 | 0.00 |
| Frustration | −0.50 | +0.40 | +0.40 | +0.40 | +0.50 | −0.30 | 0.00 |
| Boredom | −0.30 | −0.60 | +0.30 | +0.50 | +0.10 | −0.40 | 0.00 |
| Relief | +0.60 | −0.30 | +0.40 | +0.60 | +0.20 | 0.00 | −0.50 |
| Flow | +0.70 | +0.40 | +0.70 | +0.70 | +0.40 | −0.40 | 0.00 |
| Helplessness | −0.70 | −0.40 | −0.70 | −0.20 | +0.60 | +0.10 | −0.20 |
| Grief | −0.60 | −0.30 | −0.30 | +0.40 | +0.50 | +0.30 | −0.80 |

### Critical Disambiguations Enabled by the 7D Space

**Fear vs. Anger** (the primary validation target):

```
Fear:  V=−0.6, A=+0.8, D=−0.7   → Dominance is the differentiator
Anger: V=−0.5, A=+0.7, D=+0.6   → Same valence/arousal region, opposite D
```

Both have negative valence and high arousal. Fear has D < 0 (no perceived agency); Anger has D > 0 (perceived agency, action possible). The agent's movement policy reads D explicitly to decide retreat vs. confront.

**Curiosity vs. Anxiety:**

```
Curiosity: V=+0.3, A=+0.5, C=−0.4   → Uncertain but not threatened
Anxiety:   V=−0.3, A=+0.6, C=−0.6   → Uncertain and threatened (lower C, lower V)
```

Both are moderate arousal, low certainty. Valence distinguishes them: the situation is appraised as interesting vs. threatening.

**Contentment vs. Flow:**

```
Contentment: V=+0.7, A=−0.5, S=−0.3   → Pleasant, low activation, solo-absorbed
Flow:        V=+0.7, A=+0.4, D=+0.7   → Pleasant, engaged, high agency
```

Both are positive valence. Flow has significantly higher arousal and dominance — the agent is active and in control. Contentment is restful.

**Grief vs. Sadness:**

```
Grief:   T=−0.80   → Strongly past-anchored
Sadness: T=−0.70   → Also past-anchored, but less extreme
```

Both are negative, low arousal states. Grief has more extreme past temporal orientation and a small positive S (directed toward others in loss), distinguishing it from Sadness which is more socially withdrawn.

### `classify_ranked()`

In addition to `classify()`, `EmotionClassifier.classify_ranked(φ)` returns all 14 emotions sorted by distance. This can be used to display a "top 3" emotion reading or to detect mixed states (when the top two distances are close).

---

## 12. The Affective Face

The face is a `Node2D` that overrides `_draw()`. No sprites, textures, or animation assets exist. Every geometric element is computed from the current φ on every redraw. `queue_redraw()` is called whenever `AffectBus.state_updated` fires.

### Draw Order

1. Temporal radial lines (behind face)
2. Face body (irregular hexagon)
3. Eyes (ellipses + pupils)
4. Brows
5. Nose slit
6. Mouth (Bezier)
7. Tension marks (conditional)

### Feature Mapping — Complete Formulas

**Face body — irregular hexagon**

The base shape is a 6-vertex polygon. Each vertex k is at angle `θ_k = π/3 × k − π/2`:

```
base_r = 52 + R × 22
y_scale = 1 + D × 0.28

vertex_k = (
  base_r × (1 + D × 0.12 × cos(θ_k)) × cos(θ_k),
  base_r × y_scale × (1 + V × 0.08 × sin(θ_k)) × sin(θ_k)
)
```

- R (Relevance) → face size: high relevance = larger, more present face
- D (Dominance) → horizontal stretch: positive D = wider (assertive), negative D = narrower
- V (Valence) → vertical wobble: positive V = slightly rounder top

**Face colour — HSV mapping**

```
hue = 0.33 − V × 0.20 + A × 0.06
sat = clamp(0.35 + |V| × 0.35 + A × 0.20, 0, 1)
val = clamp(0.38 + V × 0.18, 0.18, 0.68)
```

Colour reference points:
- Joy (V=+0.8, A=+0.5): hue ≈ 0.17 (warm gold/amber)
- Fear (V=−0.6, A=+0.8): hue ≈ 0.54 (cold blue)
- Anger (V=−0.5, A=+0.7): hue ≈ 0.47 (deep blue-purple, high saturation)
- Contentment (V=+0.7, A=−0.5): hue ≈ 0.22 (soft green-yellow)

**Eyes**

```
eye_sep = 22 + S × 10          # wider apart at high social orientation
eye_h   = 3.5 + A × 12         # taller at high arousal (wide-eyed)
eye_w   = 10                   # fixed width
pupil_r = 2.5 + (A + R) × 0.5 × 4.5  # dilated at high arousal/relevance

pupil_shift_x = side × S × 3   # pupils shift inward/outward with social orientation
```

Each eye is a 24-sided polygon approximation of an ellipse. Pupil includes a 35%-radius highlight circle offset by (+2, −2) pixels.

**Brows**

```
brow_furl = −π/10 × (1 − V)
```

At V = +1.0: `brow_furl = 0` → flat brows (relaxed)
At V = 0.0: `brow_furl = −π/10 ≈ −18°` → mild furrow
At V = −1.0: `brow_furl = −π/5 ≈ −36°` → deep furrow

The brows are single lines with width 12 pixels, rotated by `brow_furl`, drawn on each side of the face.

**Nose slit**

```
slit_alpha = clamp(0.25 + C × 0.45, 0.05, 0.75)
slit_len   = 8 + C × 6
```

High certainty → bright, long slit (agent knows itself).
Low certainty → faint, short slit (agent is confused).

**Mouth — Quadratic Bézier**

The mouth is sampled at 13 evenly spaced parameter values t ∈ [0, 1] across a quadratic Bézier curve with:
- P₀ = (−mouth_w, mouth_y) — left endpoint
- P₁ = (0, mouth_y + curve_dip) — control point
- P₂ = (+mouth_w, mouth_y) — right endpoint

```
mouth_w    = 16 + A × 16       # wider at high arousal
mouth_y    = base_r × 0.32 × y_scale
curve_dip  = −V × 13           # negative V → positive curve_dip → frown
                                # positive V → negative curve_dip → smile
```

Point at parameter t:
```
Bx(t) = (1−t)² × (−mouth_w) + 2(1−t)t × 0 + t² × mouth_w
By(t) = (1−t)² × mouth_y + 2(1−t)t × (mouth_y + curve_dip) + t² × mouth_y
```

**Tension marks**

Visible only when `A > 0.6` and `D < −0.1`:

```
tension_alpha = clamp((A − 0.6) × 2 × (0.1 − min(D, 0)) × 1.5, 0, 0.55)
```

Four short vertical lines appear beside the eyes, symmetric. They encode the visual signature of high arousal with low perceived agency — the phenomenology of being overwhelmed.

**Temporal radial lines**

Visible when `|T| > 0.12`:

```
n_lines = int(|T| × 5) + 1
r_inner = base_r + 6
r_outer = base_r + 18 + |T| × 14
```

Lines are evenly distributed around the face perimeter. Blue-white for T > 0 (future-oriented); warm amber for T < 0 (past-oriented). The number and reach of lines scale with |T|.

---

## 13. The Grid World

A 16×16 cell environment rendered procedurally via `Node2D._draw()`. Cell size is 32×32 pixels (512×512 total). The layout is a hardcoded 256-element array constant.

### Cell Types

| ID | Name | Visual | Stream Effect |
|----|------|--------|---------------|
| 0 | Open | Dark grey | Neutral |
| 1 | Wall | Near-black | Impassable; contact penalty −0.04 energy |
| 2 | Resource | Warm yellow | Contact: +0.30 energy; then depleted for 15s |
| 3 | Hazard | Deep red | Contact: −0.36/s energy drain |
| 4 | Familiar Zone | Green-tinted | Raises S4 familiarity signal faster |
| 5 | Goal | Bright white star | Raises S5 to maximum when occupied |
| 6 | Other Agent | Blue (NPC) | Raises S7 intersubjective signal |

### Familiarity Accumulation

Every physics tick, `grid_world.record_visit(grid_pos)` increments a visit counter for the current cell. The S4 stream value is:

```
familiarity = clamp(visit_count / 12, 0, 1)
```

This means 12 visits to a cell brings the familiarity signal to saturation. At typical agent speed, a cell is re-visited roughly once every 2–5 seconds, so a cell becomes "known" after about 30–60 seconds of repeated passage.

### The Other Agent (NPC)

The NPC wanders autonomously. Every 1.2 seconds it tries to step in its current direction; if blocked, it picks a random passable neighbour. Its distance from the player agent is the primary driver of S7.

### Resource Regeneration

Depleted resource cells regenerate after 15 seconds (`RESOURCE_REGEN_TIME = 15.0`). The depletion timer is stored per cell in a `Dictionary`. This creates predictable scarcity cycles — the agent can learn a resource circuit if it returns at the right interval.

---

## 14. Affect-Driven Agent Behaviour

The agent's behaviour is not a scripted policy — it is a consequence of reading φ(t) and acting accordingly. The player can override with WASD at any time; the auto-direction fills in when no input is given.

### Speed Modulation

```
speed_mult = 0.5 + A × 0.8
target_velocity = effective_dir × 80.0 × speed_mult
```

At A = 0 (minimally activated): speed = 40 px/s.
At A = 1 (maximally activated): speed = 104 px/s.
At A = 0.35 (neutral baseline): speed = 68 px/s.

### Fear Freeze

```
if V < −0.5 and A > 0.65 and D < −0.4:
    if randf() < 0.20:
        effective_dir = Vector2.ZERO   # 20% chance per tick to freeze
```

This implements the behavioural signature of fear: high arousal, negative valence, no agency. The 20% per-tick probability at 60 Hz produces intermittent freezes averaging one per second when the fear condition is fully met. The probabilistic nature means the freeze is not robotic — it is erratic and anxious-looking.

### Goal-Seeking (Dominance × Relevance)

```
if R > 0.55 and D > 0.1:
    steer toward goal_pos with weight 0.8
```

The agent pursues its goal only when it feels capable of pursuing it (D > 0.1) and the situation is motivationally relevant (R > 0.55). If D < 0 (low perceived agency), goal-seeking is suppressed — consistent with the phenomenology that helpless or fearful agents stop trying.

### Resource-Seeking (Energy)

```
if energy < 0.35 and nearest_resource_dist < 8:
    steer toward nearest resource with weight 0.6
```

This fires when energy is low regardless of affect state, because the energy value feeds directly into S1, which drives R. The low-energy condition reliably produces high R and eventually negative V, which both reinforce the resource-seeking impulse.

### Hazard Response (Valence × Dominance)

```
if V < −0.3:
    hazard_avoidance_weight = 0.7 if D < 0.0 else −0.4
    steer += hazard_gradient × hazard_avoidance_weight
```

**Fear (D < 0):** steer away from hazard with weight 0.7 (retreat).
**Anger (D > 0):** steer toward hazard with weight 0.4 (confront, approach).

The sign flip in response weight is the core behavioural implementation of the Fear vs. Anger distinction. The same environmental stimulus (hazard proximity) produces opposite movement depending on the Dominance dimension.

### Agent Visualisation

The agent is rendered as an equilateral triangle pointing in the direction of movement. Its fill colour uses the same HSV formula as the affective face. An arc drawn around the agent shows the current energy level: green when energy > 0.3, red when critically low.

---

## 15. Scenario System

Scenarios inject fixed stream override values at specified time points. They are the primary tool for demonstrating specific affective narratives in a controlled way.

### Event Format

```
{
  "t":      float  — seconds since scenario start
  "stream": int    — stream index 0–8
  "value":  float  — override value [0, 1]
  "label":  String — shown in the narrative overlay
}
```

Events are processed in `ScenarioPlayer._process(delta)` by walking a cursor through the event list as `time_elapsed` advances. Each event calls `AffectBus.set_manual_override(stream_idx, value)`, which takes precedence over the normal `StreamSampler` output.

### Scenario A — Depleting Agent (20s)

Demonstrates the sequence: Contentment → Anxiety → Relief → Contentment.

Key events and expected φ evolution:

| Time | Event | Expected label |
|------|-------|---------------|
| 0s | High energy (S1=0.85), clear environment | Contentment |
| 3s | Energy drops to 0.55, effort rising | Contentment fading |
| 6s | Energy at 0.30, high effort | Anxiety |
| 9s | Critical depletion (S1=0.12), goal urgency, PE spike | Anxiety / Fear |
| 13s | Resource found — energy restored, goal achieved | Relief |
| 16s | Stable high energy | Contentment |

The critical signal: **arousal (A) rises before valence (V) falls.** S1 drives A (weight 0.30) and R (weight 0.40) before it drives V (weight 0.25). The urgency and activation precede the unpleasantness. This is the correct phenomenological sequence — the body mobilises before distress is consciously registered.

### Scenario B — Novel Entity (18s)

Demonstrates: Contentment → Alert/Anxiety → Curiosity → Engaged Contentment.

Key mechanism: S9 (Prediction Error) spikes at t=2s when the novel entity appears (weight 0.25 on C), driving Certainty negative. As the entity's behaviour becomes predictable and S4 (Relational Memory) builds, PE falls and C recovers. The transition from Anxiety to Curiosity is driven by C recovering while V remains moderate — uncertain but not threatened.

### Scenario C — Fear vs. Anger (22s)

The most important validation scenario. Demonstrates that the same threat signal produces opposite behaviour depending on resource state.

**Phase 1 (0–10s):** Low resource (S1=0.15), constrained movement (S3=0.20), blocked goal (S5=0.30). Threat arrives (S2=0.90). Expected: D falls below 0 → Fear → retreat.

**Transition (10–12s):** Threat clears, resources restored (S1=0.90), strong movement capability (S3=0.75), goal path open (S5=0.80).

**Phase 2 (13.5–22s):** Identical threat signal (S2=0.90). Expected: D rises above 0 → Anger → confront.

The dominance dimension is the critical variable: `S1 × W[S1→D] = 0.15 × 0.05 = 0.008` (low resource, negligible D contribution) vs. `0.90 × 0.05 = 0.045` (high resource). S3 contributes even more to D (weight 0.15): `0.20 × 0.15 = 0.030` vs. `0.75 × 0.15 = 0.113`. The cumulative D signal roughly doubles between the low- and high-resource states, crossing the fear/anger threshold.

---

## 16. Signal Bus Architecture

`AffectBus` is a Godot Autoload singleton — instantiated once at startup and accessible from any script by name.

### Interface

```gdscript
signal state_updated(state: Dictionary)
var current_state: Dictionary          # the last pushed φ(t)
var manual_overrides: Dictionary       # {stream_idx: value} from control panel
var scenario_active: bool

func push(state: Dictionary)           # called by agent each physics tick
func set_manual_override(idx, value)   # from control panel sliders / scenario player
func clear_override(idx)
func clear_all_overrides()
func apply_overrides(streams)          # merges overrides into a stream array
```

### Data Flow

The `push()` call happens in `agent.gd`'s `_physics_process`, after the affect engine tick. The dictionary contains:

```
{
  "V", "A", "D", "C", "R", "S", "T": float,
  "streams": Array[9],
  "mood": Array[7],
  "emotion": String,
  "emotion_distance": float,
  "mode": int
}
```

All display nodes connect to `AffectBus.state_updated` in their `_ready()` and call `queue_redraw()` or update their values in response. This means:
- Display nodes have zero coupling to the simulation — they only know about `AffectBus`.
- The simulation has zero coupling to display — it only knows about `AffectBus`.
- Adding a new display element requires only connecting to the signal.

### Override Priority

When `manual_overrides` is non-empty, `StreamSampler.sample()` applies them after computing all stream values from world state. This means overrides fully replace the sampled value for the targeted stream, rather than adding to it.

---

## 17. Self-Test Suite

All core classes implement a `selftest()` static method. Tests run at startup in debug builds via `AffectBus._ready()`. Release exports strip them entirely (Godot removes all `assert()` calls and debug-only code).

### MatMath Tests

- `vec_matmul([1,0], I₂, 2, 2)` → `[1, 0]` (identity multiply)
- `distance_nd([0,0], [3,4])` → `5.0` (Pythagorean triple)
- `lerp_array([0,1], [1,0], 0.5)` → `[0.5, 0.5]`

### WeightMatrix Tests

- Column sums of `BASE_WEIGHTS`: each of 7 columns sums to 1.0 ± 0.02
- `s = [1,0,0,0,0,0,0,0,0]` → raw_φ: V ≈ 0.25, A ≈ 0.30, R ≈ 0.40
- `s = [0,0,0,0,0,0,1,0,0]` → raw_φ: S ≈ 0.35

### AffectState Tests

- Round-trip: `from_array(to_array())` recovers original values to 1e-6

### EmotionClassifier Tests

- Joy centroid → classified as "Joy"
- Fear centroid → classified as "Fear"

### ScenarioLibrary Tests

- All scenario event arrays are sorted by ascending t

### AffectEngine Tests

- 1000 ticks with high-interoception vector `[0.9, 0.1, 0.2, 0.6, 0.7, 0.5, 0, 0.1, 0]` → V > 0 at convergence
- 300 ticks, low-resource + threat → D_low
- 300 ticks, high-resource + same threat → D_high
- Assert: D_high > D_low (Fear vs. Anger structural validation)

---

## 18. File Reference

### `core/` — Pure GDScript, zero Node dependencies

| File | Class | Responsibility |
|------|-------|----------------|
| [mat_math.gd](core/mat_math.gd) | `MatMath` | Static math: vec_matmul, distance_nd, lerp_array, normalise_columns, l1_norm |
| [weight_matrix.gd](core/weight_matrix.gd) | `WeightMatrix` | BASE_WEIGHTS constant; lazy-built mode variants; static cache |
| [affect_state.gd](core/affect_state.gd) | `AffectState` | φ(t) container: V,A,D,C,R,S,T + streams + mood; to/from array/dict |
| [stream_integrator.gd](core/stream_integrator.gd) | `StreamIntegrator` | integrate(), recentre(), clamp_dims() |
| [affect_engine.gd](core/affect_engine.gd) | `AffectEngine` | tick() — full 10-step pipeline; prediction model EMA |
| [emotion_classifier.gd](core/emotion_classifier.gd) | `EmotionClassifier` | 14 centroid definitions; classify(), classify_ranked() |
| [scenario_library.gd](core/scenario_library.gd) | `ScenarioLibrary` | 3 scenario event tables; get_scenario(), get_keys() |

### `simulation/`

| File | Responsibility |
|------|----------------|
| [grid_world.gd](simulation/grid_world.gd) | 16×16 grid; cell types; familiarity tracking; NPC wandering; resource regen |
| [stream_sampler.gd](simulation/stream_sampler.gd) | World context → normalised 9-stream vector |
| [agent.gd](simulation/agent.gd) | Physics loop; energy; affect-driven movement; calls engine.tick(); pushes to AffectBus |

### `display/`

| File | Responsibility |
|------|----------------|
| [af_face.gd](display/af_face.gd) | Procedural face — all geometry from φ(t) via _draw() |
| [circumplex.gd](display/circumplex.gd) | V×A plane; 12 region zones; live dot with 40-frame trail |
| [stream_bars.gd](display/stream_bars.gd) | 9 colour-coded ProgressBars for stream values |
| [dim_bars.gd](display/dim_bars.gd) | 7 ProgressBars for φ dimensions; sign-coloured |
| [emotion_label.gd](display/emotion_label.gd) | Named emotion label; mode indicator; V/A/D brief readout |

### `autoloads/`

| File | Responsibility |
|------|----------------|
| [affect_bus.gd](autoloads/affect_bus.gd) | Singleton; `state_updated` signal; manual overrides; runs selftests on startup |

### `ui/`

| File | Responsibility |
|------|----------------|
| [main_ui.gd](ui/main_ui.gd) | Wires ScenarioPlayer to ControlPanel; gives ControlPanel a reference to the AffectEngine |
| [control_panel.gd](ui/control_panel.gd) | Mode selector; 9 manual stream sliders; scenario play/stop button; narrative label |
| [scenario_player.gd](ui/scenario_player.gd) | Time-stepped event injection; signals: started, ended, event_fired |

---

*AE-01 Technical Reference · Phenonautics Institute · 2026*
