# C1-t test gate repair (qa, 2026-10-28)

Starting point d54240d: 597 cases, 596 pass. Result: 597/597 in 3 of 3 full runs after the fix.

## 1. pause_6a_test > test_a_hit_stop_that_ended_during_the_pause_does_not_come_back

Not a game bug. The test waited with `create_timer(t, true, false, true)` (ignore_time_scale). Godot divides
the frame delta by the CURRENT `Engine.time_scale`. The frame in which `Juice.hit_stop(0.05, 0.1)` sets the
scale to 0.1 had been timed at 1.0, so it is counted 10x and the "0.1 s" timer fires early. Measured probe:
a 0.1 s ignore_time_scale timer fired after 76 ms when started at scale 0.1 (about 103 ms otherwise). The
whole test finished in about 60 ms, so the 50 ms hit-stop's wall-clock end had not yet been seen by
`Juice._process` (it only ends the hit-stop on a frame at or after resume time). `GamePause.pause()` then
froze a still-running 0.05 s hit-stop and `resume()` correctly restored scale 0.1. The assertion saw 0.1.
Failure rate before the fix: 4 of 5 runs alone (it passed the one time the first frame was slow).

Fix: new `tests/support/test_clock.gd` (`TestClock.wait_real`) polls `Time.get_ticks_msec()` across
`process_frame` and ends with one extra frame. `pause_6a_test._real_wait` and the two waits in
`slice6_qa_test` (death beat, lines 230 and 233) now use it. Test intent and assertions are unchanged.

Game-code note (non-blocking, for gameplay-dev): `Main._on_player_died` (src/main/Main.gd:70) uses the same
ignore_time_scale timer right after `Juice.slow_mo(...)`, so Game Over can appear up to about 10 x one
frame early (a few tens of ms at most, not a logic bug). If exact timing matters, count from
`Time.get_ticks_msec()` instead.

## 2. slice6_qa_test > test_f1_same_seed_crowd_is_bit_identical...

Not directly caught in the act (it passed in 6 of 6 full or isolated runs here, so the original frequency is
low). What was established:
- The crowd sim is NOT invariant to `Engine.time_scale`. Probe: same seed, 300 physics ticks; a 30-frame
  `time_scale = 0.1` excursion in the middle moved enemies by up to 0.036. A fixed OS hitch (120 ms sleeps)
  moved nothing (drift 0.0), so it is time scale, not frame time or physics tick count.
- `Juice.hit_stop` and `slow_mo` end by wall clock, so any hit-stop still running when the test starts, or
  started late by an earlier test's coroutine, flips the scale for a few frames at a point that varies
  between runs. A brief excursion gives a drift of the 1e-4 order seen in the full runs.
- The earlier ignore_time_scale timers (item 1) made that more likely: they let tests move on before a
  hit-stop had ended.
I did not identify which earlier test supplied the stray hit-stop; this is a diagnosis by mechanism, not by
catching it.

Fix (test only): `_aligned_crowd` sets `Juice.hit_stop_enabled = false` (the switch the sims use) and calls
`Juice.reset()` before starting, asserts `Engine.time_scale == 1.0` on every tick with a message naming the
tick, and `after_test` restores `hit_stop_enabled = true`. If a stray slow-down ever returns it will now fail
with that message instead of a position drift.

Open question for gameplay-dev (not a bug in the test's scope): why does `Engine.time_scale` change enemy
positions at all, given fixed-step `_physics_process(delta)`? Probably physics-tick count versus frame
interaction in Godot, not game code, but it means a hit-stop mid-fight is not a pure time dilation for
enemy movement. Repro: the probe above (spawn 10 chasers, set `Engine.time_scale = 0.1` for 30 physics frames
of 300, compare end positions to an unscaled run).

## 3. New flake seen once (not fixed): attack_meter_test > test_meters_track_player_and_heavy_ready_state

In one of the three runs before the fix, at line 58 `heavy.state()` was "ready" (expected "windup"), progress
1.0, and the 1.97 s test then failed lines 59 and 60. It passed alone in 6 of 6 runs and with its two
predecessor suites (aim_getters, attack_controller) in 4 of 4 runs, and in 3 of 3 post-fix full runs, so it
is not reproduced and I have no root cause. The test releases heavy after only 2 physics frames and then reads
the wind-up state after one process frame, which depends on the press latch being consumed and the wind-up
window (a game-time value) not having passed; a long frame hitch would break that. Left unchanged rather than
loosened without evidence. Suggest: if it recurs, poll for "not ready" with a deadline before the assertion,
and capture `Engine.time_scale` and the frame count in the failure message.

## Proof (all with the README gdUnit command, headless, Godot 4.7.2 console build)

| Run | Result |
| --- | --- |
| pause_6a_test alone, before fix | 4 of 5 runs failed (1 failure each) |
| pause_6a_test alone, after fix | 9/9 pass, 3 of 3 runs (plus 3 more earlier in the session) |
| slice6_qa_test alone, after fix | 27/27 pass, 3 of 3 runs |
| Full suite, after fix | 597/597 pass, exit 0, 3 of 3 runs (about 3.5 min each) |
| Full suite, before fix | 2 runs 597/597; 1 run 3 failures in attack_meter_test (item 3) |

Files: `tests/support/test_clock.gd` (new), `tests/unit/pause_6a_test.gd`, `tests/unit/slice6_qa_test.gd`.
No `src/` changes. A new `class_name` was added, so run `godot --headless --editor --quit --path .` once to
refresh the class cache (done here).
