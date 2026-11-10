# bounce 0.3.2

A bouncing-ball sequencer for Norns and nb voices. No grid required.

Balls fall, drift sideways and trigger notes on floor impacts. Left is low pitch; right is high. Impact speed sets velocity. Each ball disappears after its assigned number of bounces. An accepted final impact can ring out.

## Trigger cap

Bounce sends at most 16 note-on triggers per second, globally across all balls, with a minimum 62.5 ms between accepted triggers. Excess impacts are dropped, never queued. Balls continue moving and counting their lifespan; only sounding impacts flash. Releases are never rate-limited. This applies to Bounce-generated notes, not manual triggers in a voice’s PARAMS. The cap reduces trigger overload; it is not an anti-aliasing filter or an audio-polyphony limit.

## Harmony and note motion

Enable **random progression** in PARAMS to loop four scale-degree triads, beginning on the tonic. **Beats per chord** sets the pacing and **reroll progression** generates a fresh loop. Chord changes apply immediately to incoming notes; held notes retain their pitch. The bottom-left readout shows the current chord.

**Pan width** maps impact position to stereo placement on nb voices advertising a per-note pan target.

**Voices** selects 1 (mono) to 16 held notes, default 8. At the limit, a new pitch releases an existing note using **voice stealing**: oldest (first), newest (last), random, lowest pitch, highest pitch, quietest (lowest trigger velocity), or loudest (highest trigger velocity). The incoming note always plays. Repeated pitches release and retrigger their own note. Lowering the voice count immediately releases excess notes using the selected policy.

These controls manage notes held by Bounce. Each nb voice controls actual audio polyphony, release tails and whether note-off ends a sound. Percussive one-shot voices can continue ringing after a steal. Increase **note length** to let chord tones overlap.

All four LFOs offer a rising saw shape.

## Controls

| Control | Action |
| --- | --- |
| E1 | Lifespan: 1–32 floor bounces |
| E2 | Density: 0–8 new balls per second |
| E3 | Gravity |
| K2 | Pause/resume physics and spawning; pause releases active notes |
| K3 | Drop one extra ball |
| K1 + E1 | Note length in seconds |
| K1 + K3 | Clear balls and release notes |

Lifespan and sideways drift are assigned when each ball is born. Changing lifespan affects new balls. Gravity and bounce elasticity affect all current balls. Ball collisions and side-wall contacts do not trigger notes. Nearly exhausted bounces retain a small rebound to avoid floor chatter.

## Sound and settings

PARAMS contains the nb voice selector, scale, lowest note, octave range, bounce elasticity, drift and four LFO groups. Each LFO has target, waveform, rate and depth. Targets: density, gravity, elasticity, drift, note length, velocity and the voice's generic nb modulation input. That last input depends on the voice (emplaitress uses timbre); unsupported voices ignore it. Modulation never rewrites the base physics parameters. Voice modulation is clamped to nb's 0–1 range; its negative half-cycle rests at zero. LFOs pause with transport.

Defaults: `emplait 1`, percussive string model, moderate decay, C natural minor. The native emplaitress envelope and timbre parameters remain in its PARAMS group. The screen's E1 changes lifespan; note length is K1+E1. In percussive voices note length may not change the sound: use the voice's decay control. No custom resonant filter or stutter is included in this release.

Select any other installed nb voice in PARAMS. If emplaitress is absent, the script starts with `none` and prompts you to select a voice. External voices require their usual MIDI/crow setup. Repeated pitches explicitly retrigger rather than allowing overlapping note-offs to cut later notes. Maximum 32 balls; actual audio polyphony is determined by the selected voice.

## Install

Copy the entire `bounce` folder into `~/dust/code/` and select `bounce`. The nb library is bundled. To use the default sound, install and enable [emplaitress](https://github.com/sixolet/emplaitress) and restart Norns first. Bounce does not install mods or modify their source.

## Validation and limits

Lua syntax checked. Automated local checks cover exact lifespans 1–32, ten simulated minutes at maximum density, ball bounds/cap, clear, and mocked Norns/nb initialization, default selection, note release, pause, voice switching, preset read and cleanup. These are simulation and API checks, not hardware audio/CPU tests. This is a first hardware-test build; Norns playback and real voice compatibility remain to be verified.

## Credits

nb by sixolet: https://github.com/sixolet/nb
Bundled unchanged `lib/nb.lua` and `lib/player.lua` from commit `400e0b3889d44b0f4f989e27e9a34f1ae732e376` (under `lib/nb/lib/`).
Emplaitress by sixolet; Plaits by Emilie Gillet; Norns by monome.
