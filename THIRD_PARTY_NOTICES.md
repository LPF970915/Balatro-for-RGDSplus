# Third-party notices

This is an unofficial RGDSplus compatibility adapter. It is not the full game.
Balatro and its original game content belong to their respective rights holders.
The user supplies a purchased, supported game file. No Steam credentials are used.
Generated game files remain on the user's device and are not part of this ZIP.

## PortMaster compatibility modules

The R4.2 baseline incorporates modules from PortsMaster/PortMaster-New,
commit `1d30f2cd7c162fb8950fc190793a046306715ffd`, under `ports/balatro`.
Source: https://github.com/PortsMaster/PortMaster-New/tree/1d30f2cd7c162fb8950fc190793a046306715ffd/ports/balatro

The repository's MIT license is retained in `LICENSE-PortMaster.txt`.
The upstream README credits nkahoang's original PortMaster work and
Guandor's Balatro Lite small-screen UI. RGDSplus changes include dual-screen
layout, input, background rendering and diagnostics.

## Runtime

The unchanged LOVE 11.5 ARM64 runtime is from PortsMaster/PortMaster-GUI,
commit `715f50fd277febf942a66d59ac31e5a9c36c2f69`,
`PortMaster/runtimes/love_11.5`.
Source: https://github.com/PortsMaster/PortMaster-GUI/tree/715f50fd277febf942a66d59ac31e5a9c36c2f69/PortMaster/runtimes/love_11.5

Bundled runtime notices are retained in `runtime/LICENSE-love.txt`.
The original R4.2 runtime binaries have not been modified.

## Patch format

`installer/recipe.lua` records hashes and copy/insert instructions.
Unchanged original bytes come exclusively from the user's game archive.
`installer/payload` contains compatibility modules and inserted patch bytes;
it does not contain a complete patched game, original artwork or audio.
Two additional background shader variants are reconstructed as deltas from
the user's original shaders, not supplied as complete original-derived shaders.

This packaging change is not a grant of permission from the Balatro rights
holders and is not a complete legal audit of every upstream contribution.
