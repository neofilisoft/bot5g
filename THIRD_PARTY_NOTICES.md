# Third-Party Notices

This project bundles the following third-party open-source library:

## Flux (tweening / easing animation library)
- Source: https://github.com/rxi/flux
- File: `libs/flux.lua`
- License: MIT (c) 2016 rxi - full text in `licenses/flux-LICENSE.txt`
- Used for: card draw/summon "fly-in" animation and hand-card hover lift effect

## Font: Kanit
- Source: https://github.com/google/fonts/tree/main/ofl/kanit (Google Fonts)
- Files: `assets/fonts/Kanit-Regular.ttf`, `Kanit-SemiBold.ttf`, `Kanit-Bold.ttf`
- License: SIL Open Font License 1.1, (c) 2020 The Kanit Project Authors -
  full text in `assets/fonts/OFL.txt`

No other third-party code is bundled. The LÖVE 11.5 runtime itself (and its
own bundled dependencies: LuaJIT/Lua, SDL2, OpenAL, enet, LuaSocket, etc.)
is distributed separately under its own zlib license by the LÖVE project
(https://love2d.org/) - see `license.txt` next to the .exe in the Windows
build for those terms.
