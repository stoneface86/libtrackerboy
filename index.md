---
layout: default
title: Home
permalink: /
---

![GitHub release (latest SemVer including pre-releases)](https://img.shields.io/github/v/release/stoneface86/libtrackerboy?include_prereleases)
![GitHub Workflow Status](https://img.shields.io/github/workflow/status/stoneface86/libtrackerboy/build)
![GitHub](https://img.shields.io/github/license/stoneface86/libtrackerboy)
[![Discord](https://img.shields.io/discord/770034905231917066?svg=true)](https://discord.gg/m6wcAK3)

# About

libtrackerboy is a support library for [Trackerboy][trackerboy-repo-link].
This library is also known as the back end of Trackerboy and is used by the
graphical front end, [Trackerboy][trackerboy-repo-link], and the command line
front end, [tbc][tbc-repo-link].

The library handles:
 * Reading/Writing trackerboy module files
 * Manipulating/reading module data
 * Gameboy APU emulation
 * Module playback
 * (Coming soon) export to [tbengine](https://github.com/stoneface86/tbengine) format.

## Use

Install [Nim](https://nim-lang.org/install.html) and then install via `nimble`:
```sh
nimble install https://github.com/stoneface86/libtrackerboy
```

See below for documentation.

## Latest releases

{% include version-table.html limit=3 %}

[Full release history]({{ '/releases/' | relative_url }})

[trackerboy-repo-link]: https://github.com/stoneface86/trackerboy
[tbc-repo-link]: https://github.com/stoneface86/tbc
