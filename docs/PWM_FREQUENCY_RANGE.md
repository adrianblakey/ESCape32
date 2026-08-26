# PWM frequency range: closing four disagreeing definitions

Why the Remora/AART boards want a higher switching-frequency ceiling than
upstream ships, what was inconsistent about how this fork implemented it,
and what it actually costs to use the top of that range.

**Status:** range fix implemented (commit `92dbf04`). Using `freq_min`
materially above 96 kHz needs `duty_spup` raised to match — see
[The real constraint](#04--the-real-constraint) below.

---

## 01 · Motivation

This fork exists to run [Remora1/AART slot-car ESC boards](https://github.com/adrianblakey/slot-car-ecom) —
AT32F421-based ESCape32 targets built for brushless motors that run well
past 10,000 Kv. Low-inductance, high-pole-count motors like these have
short electrical time constants, so at a low PWM switching frequency the
ripple current per switching cycle is large relative to the average
current:

- Increased winding losses and heating
- Coarser torque control
- Potential demagnetisation at light load

Raising the switching frequency shrinks that ripple, smooths torque
delivery, and quiets the motor. Upstream ESCape32 ships a documented
`freq_min`/`freq_max` ceiling of 48/96 kHz — comfortable for motors up to
roughly 10,000 Kv, but the project's own field notes call for headroom up
to 150 kHz for the highest-Kv motors it runs.

> Raising the PWM frequency reduces ripple current, smoother torque
> delivery, and reduces audible noise. 48–96 kHz is already good for most
> motors up to ~10,000 Kv. For very high Kv motors (>15,000 Kv), 96–150 kHz
> may provide measurable benefit.
>
> — [slot-car-ecom wiki — Why high-Kv motors benefit from higher PWM frequencies](https://github.com/adrianblakey/slot-car-ecom/wiki#why-high-kv-motors-benefit-from-higher-pwm-frequencies)

## 02 · What was found

An extended range had already been added in stages across several earlier
commits, but each landed in only one of the places that constrain
`freq_min`/`freq_max` — and a later upstream sync (rev14 → rev17)
introduced a fourth. None of the four agreed with each other:

| Code path | `freq_min` | `freq_max` |
|---|---|---|
| `checkcfg()` — `src/util.c:435` | 24–96 | 24–200, **no floor at min** |
| DSHOT cmd 41 — `src/io.c:519` | 48–152 | `[freq_min–152]` |
| CRSF config — `src/prog.c:28` | 16–48 | 16–96 |
| **Unified fix (all four sites)** | **48–152** | **48–152** |

## 03 · Why it mattered

Two of the four disagreements were live bugs, not just untidy comments.

**01 — The 152 kHz ceiling didn't survive a reboot.**
`checkcfg()` runs unconditionally at every boot, right after the saved
config is copied out of flash (`src/main.c:564`). Its old clamp capped
`freq_min` at 96 — so any value above 96 dialed in through the DSHOT
beep-programming sequence (which allowed up to 152) got silently reverted
the next time the ESC power-cycled. The setting would work until you
turned it off.

**02 — `freq_max` could end up lower than `freq_min`.**
The clamp on `freq_max` used to floor at `cfg.freq_min`, guaranteeing
max ≥ min. A later edit changed that floor to a fixed 24, dropping the
guarantee. That invariant is load-bearing: `src/main.c:747` ramps the
switching frequency from `freq_min` up to `freq_max` across the
30–60 kERPM band. If `freq_max` came in under `freq_min`, the ramp would
run backwards — frequency *falling* as the motor spins up.

**03 — The modern config path couldn't reach the extended range at all.**
The rev17 sync brought in `src/prog.c`, upstream's new CRSF-based
configuration protocol, replacing the old plain-text CLI. It still
declared the original 16–48 / 16–96 kHz range to the radio-side
configurator — so short of the DSHOT beep sequence, there was no way to
dial in anything above 96 kHz.

## 04 · The real constraint

152 kHz is selectable — using it means turning up `duty_spup` too.

Every AT32F421 target — every AART/Remora board this fork exists for —
defines a fixed comparator-blanking window: `IFTIM_BLANK_US 4`
(`mcu/AT32F421/config.h:26`). At the ESC's base commutation state,
`src/main.c:311–322` loads that value straight into `TIM1_CCR5`, the same
timer that generates the PWM edge — `4 µs × CLK_MHZ(120) = 480 counts`,
versus 512 for the legacy fallback (`IFTIM_ICFL << 2`) — close by design,
and slightly tighter.

### Why this lives in config.h, not an `#ifdef AT32F4` guard

`AT32F4` is a compiler flag the build system injects for every AT32-family
target — a chip-family flag, not a board one. `IFTIM_BLANK_US` is a
board/gate-driver tuning value: a different AT32F4 target with a different
gate driver could need a different blanking duration entirely. Putting it
in `config.h` lets each target set its own value, or omit it and fall back
to the legacy `IFTIM_ICFL << 2` behaviour — consistent with how every
other per-target knob in this codebase already works.

### The window doesn't shrink as freq_min rises — the period does

480 counts of blanking is fixed. The PWM period is not — it's
`ARR = CLK_KHZ / freq_min`, so it gets shorter as `freq_min` climbs, and
the blanking window eats a growing share of every switching cycle. For the
on-pulse to ever clear that window during spin-up, `duty_spup` has to grow
with it:

| freq_min | ARR | blank (counts) | blank % | min safe `duty_spup` |
|---|---|---|---|---|
| 48 kHz | 2500 | 480 | 19.2% | ≥ 20 |
| 64 kHz | 1875 | 480 | 25.6% | ≥ 26 |
| 96 kHz | 1250 | 480 | 38.4% | ≥ 40 |
| 152 kHz *(extrapolated)* | 789 | 480 | 60.8% | ≥ 62 |

The 48–96 kHz rows come from direct analysis of the blanking mechanism;
the 152 kHz row is the same formula carried to this fork's new ceiling.
It lines up with the deployed targets: every AART target already runs
`FREQ_MIN=48`, and their `DUTY_SPUP` values (25 for `AART1`, 20 for the
rest) sit right at the ≥20 floor this table computes for 48 kHz. That's
not a coincidence; it's the constraint already priced into the current
targets.

So `48–152` is the range the firmware will now *accept*, not a claim that
the whole range is drop-in safe at any duty setting. Pushing a board's
`freq_min` materially past 96 kHz means raising `duty_spup` to match
(≥ 62 at 152 kHz per the table above) — otherwise the spin-up on-pulse can
land entirely inside the blanking window and the ESC loses the very signal
it needs to commutate cleanly at startup.

## 05 · Verification

- All four code paths (`checkcfg`, DSHOT cmd 41, the `main.c` default
  comment, and the CRSF `CFG_MAP`) now agree on 48–152 kHz for both fields
- `freq_max`'s clamp floor is `cfg.freq_min` again — the high-RPM ramp
  can't run backwards
- Full rebuild via `docker/build.sh` — 48 ESC targets plus bootloaders (at
  the time of the fix), zero errors, zero ROM overflows
- No change to the deployed AART/Remora defaults (still 48/96 kHz) — this
  widens what's *selectable*, not what ships

## Sources

- [slot-car-ecom wiki — PWM frequencies](https://github.com/adrianblakey/slot-car-ecom/wiki#why-high-kv-motors-benefit-from-higher-pwm-frequencies)
- [fix commit 92dbf04](https://github.com/adrianblakey/ESCape32/commit/92dbf04)
- [aartech-dev/ESCape32 target definitions](https://github.com/aartech-dev/ESCape32/blob/master/CMakeLists.txt)
- [blanking-window analysis](https://claude.ai/chat/031514f6-3440-4648-a4ee-98bd232a2894) (private chat — summarized above)
