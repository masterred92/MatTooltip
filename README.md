<p align="center"><img src="media/logo.png" alt="MatTooltip logo" width="200"></p>

# Mat Tooltip (WoW: Forever) v0.4.0

[![Tests](https://github.com/masterred92/MatTooltip/actions/workflows/tests.yml/badge.svg)](https://github.com/masterred92/MatTooltip/actions/workflows/tests.yml) [![WoW: Forever](https://img.shields.io/badge/WoW%3A%20Forever-Interface%2016001-c8a165)](https://github.com/masterred92/MatTooltip/blob/main/MatTooltip.toc) [![Release](https://img.shields.io/github/v/release/masterred92/MatTooltip?label=release)](https://github.com/masterred92/MatTooltip/releases) [![License: MIT](https://img.shields.io/github/license/masterred92/MatTooltip)](https://github.com/masterred92/MatTooltip/blob/main/LICENSE) [![CurseForge](https://img.shields.io/badge/CurseForge-MatTooltip-f16436)](https://www.curseforge.com/wow/addons/mattooltip) [![Wago](https://img.shields.io/badge/Wago-MatTooltip-c1272d)](https://addons.wago.io/addons/mattooltip)

Adds lines to item tooltips for **Leather (Skinning) and Herb** trade goods:
- **AH (your scan)**: the lowest per-unit buyout from your newest full AH scan (this addon's or PriceLog's).
- **Vendor**: the vendor sell price.
- **NEVER VENDOR**: a flag for scarce mats. The list is seeded with Pristine Leather 249427 and Frilled Lichen 249399, and you can edit it.
- One verdict, **SELL ON AH**, **VENDOR** or **HOLD**:
  - SELL ON AH when the AH price after the 5% faction cut beats vendor by 10% or more; otherwise VENDOR.
  - HOLD when there's no scan yet. Never-vendor mats are never VENDOR.
  - A scan older than 3 days adds "price is old".

It never buys, sells, posts or clicks anything. The scan only runs when you type the command.

**New in 0.3.0**
- **Bagnon bag markers:** with Bagnon, Skinning and Herbalism mats in your bags get a small **SELL**, **VEND** or **?** tag, so you can see the verdict without hovering. `/mattip bagnon` turns them off.
- **LDB display:** with Titan Panel, ChocolateBar, Bazooka or another LibDataBroker display, it shows what your bag mats would fetch on the AH after the cut, with the verdict for each in the tooltip.

**Works with:** PriceLog (uses its prices and shows its 7-day trend; no second price store), NeutralFlip (one tooltip block, no repeated AH price), GoldPerSpot (shows the sell-or-craft verdict on your loot). Works fully on its own.

## Download
- **CurseForge:** https://www.curseforge.com/wow/addons/mattooltip (first release coming at launch, Nov 4). Author: [MasterRed92](https://www.curseforge.com/members/masterred92/projects).
- **Wago Addons:** https://addons.wago.io/addons/mattooltip (first release coming at launch, Nov 4).
- **GitHub:** [Releases](https://github.com/masterred92/MatTooltip/releases) (coming with the first tagged release) · [Issues](https://github.com/masterred92/MatTooltip/issues)
- **Companion addons** (optional, they share AH scans): [NeutralFlip](https://github.com/masterred92/NeutralFlip) · [PriceLog](https://github.com/masterred92/PriceLog) · [GoldPerSpot](https://github.com/masterred92/GoldPerSpot)

## Commands
`/mattip scan` (at an open AH, out of combat; about once per 15 minutes) · `never <id|link>` · `unnever <id>` · `list` · `margin 1.1` · `toggle` · `plugins` · `report`

Upgrading from 0.1.0: your settings and prices move to `KennyMatTooltipDB` automatically on first login.

## Install
1. Download the addon zip (see Download above) or clone this repo into a folder named `MatTooltip`.
2. Put the addon folder (`MatTooltip`) in `World of Warcraft\_forever_\Interface\AddOns\`. That folder sits next to `_retail_`; the exact name may differ.
3. Restart the game, or type `/reload`. Check it is ticked in the AddOns list on the character screen.

## In-game test checklist
1. MatTooltip appears in the AddOns list, not "out of date". `/mattip` prints help.
2. Hover Light Leather / Peacebloom: HOLD "(scan the AH first)". Cloth or ore: no extra lines.
3. Hover Pristine Leather / Frilled Lichen: red NEVER VENDOR flag.
4. At a faction AH, `/mattip scan`: "saved prices for N mats" within about a minute, with no lag spike or Lua error.
5. Tooltips now show AH prices, and the verdicts look sensible against the AH's own prices.
6. `/mattip never <link>`, then `/reload`: the flag persists.
7. With another tooltip addon on (e.g. Polestar), both addons' lines show and neither disappears.
8. Hover mats in combat: no errors, no "action blocked" or taint messages.
9. If 0.1.0 was installed before: the old settings and prices carried over.
10. `/mattip report`: a copyable window opens with the client build.
11. In the AddOns list (character select or Esc > AddOns), MatTooltip shows its icon. If it shows a blank or green square, report it; the addon still works.
12. With Bagnon: open your bags. Herbs and leather show SELL, VEND or ?, other items show nothing. `/mattip bagnon` hides and shows the tags. Cached (other character) bags don't error.
13. With Titan Panel or ChocolateBar: the Mats display shows the bag value; hover lists each mat.

## Development
`tests/run.sh [path-to-wow-ui-source-forever]` runs `luac -p`, luacheck, the mock-client tests and (with a path) the API check against Blizzard's UI source. GitHub Actions runs the same on every push. Releases are packaged by [BigWigsMods/packager](https://github.com/BigWigsMods/packager) only when a `v*` tag is pushed.
