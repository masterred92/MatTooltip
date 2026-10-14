#!/usr/bin/env python3
"""Check every WoW API/global/event used by the addon exists in Gethe/wow-ui-source (forever branch)."""
import re, sys, subprocess, pathlib
SRC = pathlib.Path(sys.argv[1]); code = pathlib.Path(sys.argv[2]).read_text()
DOC = SRC / "Interface/AddOns/Blizzard_APIDocumentationGenerated"
docs = "".join(p.read_text(errors="ignore") for p in DOC.glob("*.lua"))
# namespace -> function names
ns_funcs = set()
for block in re.split(r'\n\tName = "', docs):
    m = re.search(r'Namespace = "(C_\w+)"', block)
    if m:
        for f in re.findall(r'\t\t\tName = "(\w+)",\n\t\t\tType = "Function"', block): ns_funcs.add(f"{m.group(1)}.{f}")
global_funcs = set()
for block in docs.split("local "):
    if 'Namespace' not in block.split("Functions")[0] if "Functions" in block else True:
        global_funcs |= set(re.findall(r'\t\t\tName = "(\w+)",\n\t\t\tType = "Function"', block))
events = set(re.findall(r'LiteralName = "(\w+)"', docs))
def in_ui(pattern):
    return subprocess.run(["rg", "-q", "-g", "*.lua", "-g", "*.xml", pattern, str(SRC / "Interface")], timeout=60).returncode == 0
used_ns = sorted(set(re.findall(r'\b(C_\w+\.\w+)\s*\(', code)))
used_ev = sorted(set(re.findall(r'RegisterEvent\("(\w+)"', code)))
checks = []
for n in used_ns: checks.append((n, n in ns_funcs, "API doc"))
for e in used_ev: checks.append((e, e in events, "event doc"))
for g in ["CreateFrame", "GetMoneyString", "InCombatLockdown", "issecretvalue", "time"]:
    ok = g in global_funcs or in_ui(rf'function {g}\(|{g} = ')
    checks.append((g, ok or in_ui(rf'\b{g}\('), "global func (doc or used by Blizzard UI)"))
for g, pat in [("GameTooltip", r'name="GameTooltip"'), ("ItemRefTooltip", r'name="ItemRefTooltip"'),
               ("TooltipDataProcessor.AddTooltipPostCall", r'function TooltipDataProcessor\.AddTooltipPostCall'),
               ("Enum.TooltipDataType.Item", r'Name = "Item", Type = "TooltipDataType"'),
               ("SlashCmdList", r'SlashCmdList\['), ("C_Timer.After", r'C_Timer\.After\(')]:
    checks.append((g, in_ui(pat), "Blizzard UI source"))
bad = [c for c in checks if not c[1]]
for n, ok, where in checks: print(("OK   " if ok else "MISS ") + n + "  [" + where + "]")
print(f"\n{len(checks)-len(bad)}/{len(checks)} verified"); sys.exit(1 if bad else 0)
