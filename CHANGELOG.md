# Changelog

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
