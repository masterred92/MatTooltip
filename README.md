# Mat Tooltip (WoW: Forever) v0.1.0

> [!WARNING]
> **Untested in-game. Use at your own risk.** WoW: Forever has not launched yet (Nov 4 2026), so none of this has run in the real client.
> - API usage is verified against Blizzard's UI source only (Gethe/wow-ui-source `forever` branch, 1.60.1 build 70374), plus luacheck and a mock harness.
> - Mat item IDs were checked against auctionhouse.fyi's Forever item data (build 1.60.1.70009), not in-game.
> - `## Interface: 16001` is unconfirmed (the UI source .toc files show `0`).
> - Found a bug? Please [open an issue](https://github.com/masterred92/wow-forever-addons/issues).

Adds lines to item tooltips for **Leather (Skinning) and Herb** trade goods:

- **AH (your scan)**: the lowest per-unit buyout from your own last full AH scan (no internet, ever)
- **Vendor**: the vendor sell price from item info
- **NEVER VENDOR**: flag for scarce mats on your list (seeded: Pristine Leather 249427, Frilled Lichen 249399; IDs confirmed in auctionhouse.fyi's Forever item data, build 1.60.1.70009)
- One verdict: **SELL ON AH** / **VENDOR** / **HOLD**
  - AH price after the 5% faction cut beats vendor by 10% or more → SELL ON AH, otherwise VENDOR
  - no scan yet → HOLD; never-vendor items are SELL ON AH or HOLD, never VENDOR; scans older than 3 days say "price is old"

## Commands
`/mattip scan` (at an open AH, out of combat; Blizzard allows about one full scan every 15 minutes) ·
`/mattip never <id|link>` · `/mattip unnever <id>` · `/mattip list` · `/mattip margin 1.1` · `/mattip toggle`

It never buys, sells, posts or clicks anything for you. The scan only runs when you type the command.

## Install
Copy the `MatTooltip` folder to `World of Warcraft\_forever_\Interface\AddOns\` (folder name may differ; it's
the one next to `_retail_`/`_classic_`). Prices are stored in `WTF\Account\<acct>\SavedVariables\MatTooltip.lua`.

## In-game test checklist
1. Addon appears in the AddOns list, not "out of date"; `/mattip` prints help.
2. Hover Light Leather / Peacebloom: HOLD "(scan the AH first)". Cloth or ore: no extra lines.
3. Hover Pristine Leather / Frilled Lichen: red NEVER VENDOR flag.
4. At a faction AH, `/mattip scan`: within about a minute "saved prices for N mats", no lag spike or Lua error.
5. Tooltips now show AH prices; verdicts look sensible against the AH's own prices.
6. `/mattip never <link>` then `/reload`: flag persists (SavedVariables work).
7. Hover mats in combat: no errors, no "action blocked" / taint messages.
8. With `/console scriptErrors 1`, play a session and note any errors.

## Dev checks
`luacheck .` · `python3 tools/verify_api.py <wow-ui-source forever checkout> MatTooltip.lua` · `lua tools/mock_test.lua`
