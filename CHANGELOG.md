# Changelog

## 0.4.3
- `/mattip toggle` says "tooltip lines on/off" instead of a bare "on"/"off".
- `/mattip margin` explains the new setting (e.g. "beats vendor by 10% or more").
- Description and Bagnon note updated: every Trade Goods item counts as a mat, not just leather and herbs.

## 0.4.2
- Prices PriceLog takes from Auctionator are labelled 'AH (Auctionator)' instead of 'AH (your scan)'.
- Prices of unknown age (e.g. from Auctionator) are no longer marked 'price is old'.
- Quieter: one-line first-login welcome, and no extra chat line after a scan when PriceLog already reports it.

## 0.4.1
- A scan that hits an error no longer leaves MatTooltip re-processing every later AH update.
- `/mattip margin` checks the value (0.5 to 10) and shows the current one.
- `/mattip list` shows item names, not just IDs.

## 0.4.0
- Every Trade Goods item now counts as a mat (cloth, herbs, ore, leather, and more).
- Uses PriceLog's prices when installed, instead of keeping a second copy, and shows PriceLog's 7-day trend.
- Tooltip: one block shared with NeutralFlip, so the AH price is never shown twice.
- A short guide on first login; one shared display-bar entry.
- `/mattooltip debug` checks your setup: client version, every game API the addon needs, and which of Kenny's other addons it is working with.
- A loud chat warning if this client is missing an API the addon needs, instead of failing silently.
- English text now lives in `Locales/enUS.lua`, ready for translations.
- Shared code (KennyShared) is identical in every addon of the family and checked in CI, along with every Blizzard API call (against the Forever UI source) and every DBM/BigWigs/Questie API call (against their source).

## 0.3.0
- Bagnon bag markers: SELL / VEND / ? on Skinning and Herbalism mats in Bagnon's bags (hooks BagBrother's item button update; `/mattip bagnon` toggles). Uses PriceLog prices too when installed.
- LibDataBroker display: AH value of your bag mats after the cut, with each mat's verdict in the tooltip. Click toggles the tooltip lines.
- Tests now fail CI on any luacheck warning, and the API check also covers Bagnon and LibDataBroker calls.

## 0.2.0 (first public release)
- Added the CurseForge and Wago project IDs to the TOC for automatic packaging, and an icon for the AddOns list (`media/icon.tga`).
- Uses PriceLog prices when they're newer, adds a tooltip-provider plugin API and `/mattip report`. Settings migrate from 0.1.0 automatically.

## 0.1.0 (2026-10-14, GitHub only)
- AH/vendor price and a SELL ON AH / VENDOR / HOLD verdict for leather and herbs, plus a never-vendor flag.
- Game version: WoW: Forever 1.60.1 (Interface 16001).
