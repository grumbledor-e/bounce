# bounce

A bouncing-ball sequencer for norns and nb. No grid or arc required.

Balls fall, drift sideways and trigger notes when they hit the floor. Horizontal position determines pitch, quantised to the selected scale. Impact speed determines velocity. Each ball disappears after its assigned number of bounces.

## Install

Run in Maiden:

```text
;install https://github.com/grumbledor-e/bounce
```

The nb library is bundled. Choose an installed nb player in PARAMS and use its controls to shape the sound.

## Controls

| Control | Action |
| --- | --- |
| E1 | Lifespan, 1–32 bounces |
| E2 | Density, 0–8 new balls per second |
| E3 | Gravity |
| K2 | Pause / resume |
| K3 | Drop one ball |
| K1 + E1 | Note length, 0.02–4 seconds |
| K1 + K3 | Clear balls and release notes |

Pausing releases held notes and freezes physics, chord progression and LFOs.

## Harmony

Set **lowest note**, **scale** and **octaves** in PARAMS.

Enable **random progression** to loop four scale-derived triads, beginning on the tonic. **Beats per chord** sets the duration of each chord using the norns clock tempo. **Reroll progression** generates a fresh loop.

Chord changes apply immediately to incoming notes. Held notes retain their pitch, allowing chords to overlap at longer note lengths.

The bottom-left readout shows the root and scale, or the current chord when progression is enabled.

## Voices and stealing

**Voices** sets the maximum number of held notes from **1 (mono) to 16**, defaulting to 8.

At capacity, **voice stealing** chooses which held note to release before playing the incoming note.

| Mode | Note released |
| --- | --- |
| Oldest (first) | Earliest triggered |
| Newest (last) | Most recently triggered |
| Random | Random held note |
| Lowest pitch | Lowest held pitch |
| Highest pitch | Highest held pitch |
| Quietest | Lowest trigger velocity |
| Loudest | Highest trigger velocity |

Repeated pitches release and retrigger their existing note. Lowering the voice count immediately releases excess notes using the selected policy.

The selected nb player determines audible polyphony and release behaviour. Percussive sounds and release tails may continue after a note is stolen.

## Modulation

Four LFOs each provide target, shape, rate and depth.

Targets include density, gravity, bounce elasticity, drift, note length, velocity and the player's generic nb modulation input. The response to **voice mod** depends on the selected player.

## nb and MIDI

Bounce sends notes, velocity and note duration through nb. Each player supplies its own synthesis, sampling or external instrument connection.

For external MIDI sequencing:

1. Connect the synth or MIDI interface before loading Bounce.
2. Select its `midi: [device]` player in PARAMS.
3. Match the MIDI channel to the receiving instrument.
4. Set **modulation CC** and assign an LFO to **voice mod** to control that CC.

Note length and voice stealing also apply to MIDI output. Set the voice count to suit the receiving synth's polyphony.

## Credits

[nb](https://github.com/sixolet/nb) by sixolet.

Bundled nb library files from commit `400e0b3889d44b0f4f989e27e9a34f1ae732e376`.

[norns](https://monome.org/norns/) by monome.
