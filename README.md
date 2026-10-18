# Mat Tooltip (WoW: Forever) v0.2.0

> [!WARNING]
> **Untested in-game. Use at your own risk.** WoW: Forever has not launched yet (Nov 4 2026), so none of this has run in the real client.
> - API usage is verified against Blizzard's UI source only (Gethe/wow-ui-source `forever` branch, 1.60.1 build 70374), plus luacheck and mock-client tests.
> - Item IDs were checked against auctionhouse.fyi's Forever item data (build 1.60.1.70009), not in-game.
> - `## Interface: 16001` is unconfirmed (the UI source .toc files show `0`).
> - Found a bug? Use the addon's `report` command and [open an issue](https://github.com/masterred92/wow-forever-addons/issues).

Adds lines to item tooltips for **Leather (Skinning) and Herb** trade goods:
- **AH (your scan)**: the lowest per-unit buyout from your newest full AH scan (this addon's or PriceLog's).
- **Vendor**: the vendor sell price.
- **NEVER VENDOR**: a flag for scarce mats. The list is seeded with Pristine Leather 249427 and Frilled Lichen 249399, and you can edit it.
- One verdict, **SELL ON AH**, **VENDOR** or **HOLD**:
  - SELL ON AH when the AH price after the 5% faction cut beats vendor by 10% or more; otherwise VENDOR.
  - HOLD when there's no scan yet. Never-vendor mats are never VENDOR.
  - A scan older than 3 days adds "price is old".

It never buys, sells, posts or clicks anything. The scan only runs when you type the command.

## Commands
`/mattip scan` (at an open AH, out of combat; about once per 15 minutes) · `never <id|link>` · `unnever <id>` · `list` · `margin 1.1` · `toggle` · `plugins` · `report`

Upgrading from 0.1.0: your settings and prices move to `KennyMatTooltipDB` automatically on first login.

## Install
1. Download the addon zip from [Releases](https://github.com/masterred92/wow-forever-addons/releases) (or copy the folder from this repo).
2. Put the addon folder (e.g. `FarmTracker`) in `World of Warcraft\_forever_\Interface\AddOns\`. That folder sits next to `_retail_`; the exact name may differ.
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
