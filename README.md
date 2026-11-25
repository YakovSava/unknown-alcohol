# Unknown Alcohol

Native module for **Casualties: Unknown**, written in **FASM x86-64** and loaded
through **Unknown Polymorphism (UP)**.

> **Important:** this mod is not global. It does not add new liquids, does not
> modify `Liquids.Registry`, does not rewrite the vanilla `LiquidType`, and does
> not touch saves. It only intercepts the local drink event and applies a local
> alcohol-strength coefficient to the body that is drinking. In essence, it
> demonstrates what Unknown Polymorphism can do: a native C ABI, hooks,
> reflection, managed handle retention, and per-frame ticks without a single
> line of C#.

## What actually changes

The vanilla `alcohol` liquid stays exactly what it is: same id, same name, same
icon, same vanilla effects. The mod does not replace it globally.

When a body drinks a liquid with `liquidId == "alcohol"`, the module measures
the amount of alcohol consumed and applies a **local** strength coefficient:

```text
points = ml * 0.95 * 0.25
```

For that drink, alcohol is treated as 95% ethanol instead of the 0.7 strength
used in Unknown Drugs. This coefficient lives only inside the module and is not
saved into the game.

## Features

- Hooks `WaterContainerItem.Drink(Body, System.Single, System.String)`.
- Uses `CalculateDrain` and `stack` to determine how much `alcohol` was
  actually consumed, even when the container holds a mixture of liquids.
- Keeps a separate intoxication state per body, up to 8 bodies.
- Caps the level at 120 and decays it by `0.03` per second.
- Mirrors the `Intoxication` thresholds from Unknown Drugs:
  - from 8: slowdown through `stimulantMultiplier` and `happiness` growth;
  - from 25: chance to call `Ragdoll()`;
  - from 50: chance to call `vomiter.Vomit()` and lose `consciousness`;
  - from 85: lose `bloodOxygen`.
- Adds `sicknessAmount += ml * 0.05`, because spirit hits harder than a normal
  drink.
- Does not skip the original `onDrink`: vanilla effects still apply.

## Unknown Polymorphism features used

- Native DLL loading through `UP_GetModule`.
- A module with no imports and no C runtime.
- `host->hook` with the `Body,System.Single,System.String` signature.
- `host->invoke`, `host->get_field`, and `host->set_field`.
- `host->retain` and `host->release` for managed handles.
- The module `tick` callback for per-frame state updates.
- Lazy hook installation: if the game type is not loaded yet, the module
  retries once per second.

## Requirements

- Casualties: Unknown (full game or Demo), Unity 2022.3 Mono.
- BepInEx 5.4.23.x.
- Unknown Polymorphism.
- Windows x64.
- FASM 1.73.30 to build from source.

## Build

```bat
build.bat
```

Or manually:

```bat
set INCLUDE=C:\Program Files\fasmw17330\INCLUDE
"C:\Program Files\fasmw17330\FASM.EXE" src\unknown_alcohol.asm build\UnknownAlcohol.dll
```

Output: `build\UnknownAlcohol.dll`.

## Install

Copy the DLL into the UP native module folder:

```text
<Game folder>\BepInEx\plugins\UnknownPolymorphism\mods\UnknownAlcohol\UnknownAlcohol.dll
```

Restart the game completely. UP does not support hot reloading of native DLLs.

The log should contain:

```text
[UP][unknown-alcohol] Unknown Alcohol loaded: vanilla alcohol is ethanol
[UP][unknown-alcohol] Unknown Alcohol: Drink hook installed
```

## Tuning

All values live in the `.data` section of `src/unknown_alcohol.asm`:

| Constant | Value | Meaning |
|---|---:|---|
| `c_strength` | `0.95` | local strength of the spirit |
| `c_points_per_ml` | `0.25` | intoxication points per ml of pure alcohol |
| `c_extra_sickness` | `0.05` | extra sickness per ml |
| `c_max_level` | `120.0` | maximum level |
| `c_decay` | `0.03` | decay per second |
| `c_tipsy` | `8.0` | tipsy threshold |
| `c_drunk` | `25.0` | drunk threshold |
| `c_sick` | `50.0` | sickness threshold |
| `c_poison` | `85.0` | hypoxia threshold |

Rebuild the DLL after changing any constant.

## Limitations

- State is stored in native memory and is not saved with the game.
- Screen distortion and drunk phrases are not included; in Unknown Drugs they
  are separate managed components.
- The mod does not create items, liquids, or recipes.
- If Unknown Drugs is installed, its own `Intoxication` also fires, so the two
  effects stack.

## Verification

The FASM build passes. The DLL loads through the loader, `UP_GetModule` returns
a valid descriptor, and the export table is readable. The full path
`hook -> CalculateDrain -> stack -> liquidId -> level -> tick` was tested with a
fake UP host:

- 100 ml: level 23.75, `stimulantMultiplier = -0.095`, `happiness` grows;
- 1000 ml: level caps at 120, `Ragdoll` and `Vomit` fire, `consciousness` and
  `bloodOxygen` drop to 0;
- decay to zero releases the retained handle.

The mod has not been launched in the real game yet.

## Also try

**Unknown Drugs** — the original mod that this module takes its alcohol and
intoxication model from. It adds 39 liquids with tolerance, addiction, and
withdrawal, and includes its own vanilla-alcohol hook.

- Nexus Mods: https://www.nexusmods.com/scavprototype/mods/1075
- GitHub: https://github.com/YakovSava/unknown-drugs
