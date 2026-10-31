---
title: 'An iPhone Duo simulator needs its own Duo-only iOS runtime'
description: 'Creating an iPhone Duo simulator with Xcode 27.2 failed with Incompatible device on iOS 27.0 and on the regular iOS 27.2 runtime. The Duo has a device-specific runtime whose identifier ends with the model ID. How to tell them apart, and what simctl cannot do.'
lang: en
translationKey: iphone-duo-simulator-runtime
publishDate: 2026-10-31
tags: ['Xcode', 'iOS', 'Simulator', 'AI']
draft: false
---

I am developing an iPhone version of [FirnPlanner](https://firnplanner.l4l4.dev/), a day planner I build on my own, and adapting it to the foldable iPhone Duo. I do not have the device, so I check it in the simulator. Tests and builds are run from the command line by an AI coding agent (Claude Code), so I tried to create the Duo simulator with `xcrun simctl` as well. I got stuck twice.

## There is an iOS 27.2 runtime, but the Duo cannot be created

With Xcode 27.2 installed, the iPhone Duo shows up in the list of device types.

```sh
$ xcrun simctl list devicetypes | grep Duo
iPhone Duo (com.apple.CoreSimulator.SimDeviceType.iPhone-Duo)
```

Creating one with the installed iOS 27.0 runtime fails, though.

```sh
$ xcrun simctl create duo com.apple.CoreSimulator.SimDeviceType.iPhone-Duo \
    com.apple.CoreSimulator.SimRuntime.iOS-27-0
An error was encountered processing the command (domain=com.apple.CoreSimulator.SimError, code=403):
Incompatible device
```

The device type in JSON says the minimum OS is 27.1.0.

```sh
$ xcrun simctl list devicetypes -j | grep -B3 '"name" : "iPhone Duo"'
      "modelIdentifier" : "iPhone19,4",
      "minRuntimeVersionString" : "27.1.0",
      "minRuntimeVersion" : 1769728,
      "name" : "iPhone Duo"
```

That part is easy to understand. What confused me was that the iOS 27.2 runtime failed with the same Incompatible device.

```sh
$ xcrun simctl create duo com.apple.CoreSimulator.SimDeviceType.iPhone-Duo \
    com.apple.CoreSimulator.SimRuntime.iOS-27-2
Incompatible device
Unable to create a device for device type: iPhone Duo (...), runtime: iOS 27.2 (27.2 - 24B8117) - com.apple.CoreSimulator.SimRuntime.iOS-27-2
```

## The Duo runtime has the model ID at the end of its identifier

`simctl list runtimes` shows several entries named iOS 27.2, and the names alone do not tell them apart. The identifiers do: one ends with `-iPhone19-4`, and `iPhone19,4` is the Duo model ID seen above.

```sh
$ xcrun simctl list runtimes | grep 'iOS 27'
iOS 27.0 (27.0 - 24A434) - com.apple.CoreSimulator.SimRuntime.iOS-27-0
iOS 27.1 (27.1 - 24A94401) - com.apple.CoreSimulator.SimRuntime.iOS-27-1
iOS 27.2 (27.2 - 24B114) - com.apple.CoreSimulator.SimRuntime.iOS-27-2
iOS 27.2 (27.2 - 24B91016s) - com.apple.CoreSimulator.SimRuntime.iOS-27-2-iPhone19-4
```

(My machine still has beta and RC runtimes, so the real list is longer.)

I counted the device types each runtime supports.

| Runtime identifier | Device types it can create |
|---|---|
| `iOS-27-0` | 62 (no Duo) |
| `iOS-27-1` | iPhone Duo only |
| `iOS-27-2` | 63 (no Duo) |
| `iOS-27-2-iPhone19-4` | iPhone Duo only |

The counts come from `supportedDeviceTypes` in `simctl list runtimes -j`. In iOS 27.2, the Duo alone is split into its own runtime. The iOS 27.1 runtime on my machine also supports only the Duo.

![Comparison diagram: the regular iOS 27.2 runtime cannot create an iPhone Duo simulator, while the Duo-specific runtime can](/TIL/images/iphone-duo-runtime-compatibility.svg)

So to create a Duo, pass the device-specific runtime. With the identifier, simctl prints the UDID of the new simulator.

```sh
$ xcrun simctl create duo com.apple.CoreSimulator.SimDeviceType.iPhone-Duo \
    com.apple.CoreSimulator.SimRuntime.iOS-27-2-iPhone19-4
CAA756E8-69C3-4762-BA55-9F10F10130CD
```

When I left the runtime out, simctl also picked the right one.

```sh
$ xcrun simctl create duo com.apple.CoreSimulator.SimDeviceType.iPhone-Duo
No runtime specified, using 'iOS 27.2 (27.2 - 24B91016s) - com.apple.CoreSimulator.SimRuntime.iOS-27-2-iPhone19-4'
```

In scripts, pass the identifier explicitly as above, not the name iOS 27.2. Selecting by name can land on the regular 27.2 runtime and fail.

## simctl cannot fold, unfold or rotate

Once it was created, I got stuck again. The Duo changes its screen shape when closed (the outer display), open in portrait and open in landscape. I wanted screenshots of each shape to check the layout, but `simctl` has no subcommand to change it. `simctl ui` only covers appearance (light or dark), increased contrast and content size.

```sh
$ xcrun simctl ui
...
Supported Options:
    appearance
    increase_contrast
    content_size
```

The closed shape could be captured as is. The two open shapes need Simulator.app to unfold and rotate the device. That step needs a person, so out of the screenshots I had left to the agent, those two are still missing.

## Summary

- An iPhone Duo simulator could only be created with iOS 27.1 or later, and only with the Duo-only runtime. For iOS 27.2, that is the one whose identifier ends with `-iPhone19-4`
- The name is the same iOS 27.2, so select by identifier. If you omit the runtime, simctl picks the device-specific one
- `simctl` cannot fold, unfold or rotate. Check the open shapes in Simulator.app

Tested with Xcode 27.2 (27B52) on macOS 27.2.
