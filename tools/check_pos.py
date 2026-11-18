#!/usr/bin/env python3
"""Offline text checks for POS-kOS guidance data. No KSP or kOS."""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "Script"

# Catalog numbers are metres: ground range, and energy height.
ENTRY_RE = re.compile(
    r'lex\(\s*"number"\s*,\s*(?P<number>\d+)\s*,\s*'
    r'"energy_min"\s*,\s*(?P<energy_min>-?\d+(?:\.\d+)?)\s*,\s*'
    r'"energy_max"\s*,\s*(?P<energy_max>-?\d+(?:\.\d+)?)\s*,\s*'
    r'"range_min"\s*,\s*(?P<range_min>-?\d+(?:\.\d+)?)\s*,\s*'
    r'"range_max"\s*,\s*(?P<range_max>-?\d+(?:\.\d+)?)\s*,\s*'
    r'"image"\s*,\s*"(?P<image>[^"]*)"\s*\)'
)
KERBIN_LITERALS = (
    ("min_range", "650000"),
    ("max_range", "1600000"),
    ("preferred_range", "850000"),
    ("max_crossrange", "120000"),
)


def fail(reason):
    print(reason, file=sys.stderr)
    raise SystemExit(1)


def read_text(path):
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        fail(f"{path.relative_to(ROOT)} is not readable: {exc}")


def function_body(text, name):
    marker = f"function {name}"
    start = text.find(marker)
    if start < 0:
        return None
    rest = text[start + len(marker):]
    nxt = re.search(r"\nfunction ", rest)
    end = start + len(marker) + (nxt.start() if nxt else len(rest))
    return text[start:end]


def check_entry_charts():
    path = SCRIPT / "Libraries/Poseidon_SSTO/entry_chart_catalog.ks"
    text = read_text(path)
    seen = 0
    for lineno, line in enumerate(text.splitlines(), 1):
        if "lex(" not in line:
            continue
        match = ENTRY_RE.search(line)
        if not match:
            fail(f"entry_chart_catalog.ks:{lineno}: unparsed catalog entry")
        seen += 1
        number = match.group("number")
        energy_min = float(match.group("energy_min"))
        energy_max = float(match.group("energy_max"))
        range_min = float(match.group("range_min"))
        range_max = float(match.group("range_max"))
        image = match.group("image").strip()
        where = f"entry chart page {number} line {lineno}"
        if energy_min > energy_max:
            fail(f"{where}: energy_min {energy_min:g} m > energy_max {energy_max:g} m")
        if range_min >= range_max:
            fail(f"{where}: range_min {range_min:g} m >= range_max {range_max:g} m")
        if not image:
            fail(f"{where}: empty image path")
        image_path = Path(image)
        if not image_path.is_absolute():
            image_path = SCRIPT / image
        if not image_path.is_file():
            fail(f"{where}: image not on disk: {image}")
    if seen == 0:
        fail("entry_chart_catalog.ks has no chart entries")
    return seen


def check_kerbin_corridor():
    body = function_body(read_text(SCRIPT / "Libraries/Poseidon_SSTO/deorbit.ks"), "deorbit_config")
    if body is None:
        fail("deorbit_config is missing")
    # Kerbin keeps the unscaled assignments. Other bodies multiply the same numbers.
    for name, value in KERBIN_LITERALS:
        if not re.search(rf"local\s+{name}\s+is\s+{value}\b", body):
            fail(f"deorbit_config Kerbin corridor missing literal {name} {value}")


def check_brake_factor():
    body = function_body(read_text(SCRIPT / "Libraries/lib_landing_sites.ks"), "landing_admit_site")
    if body is None:
        fail("landing_admit_site is missing")
    if not re.search(r"brake_accel\s+is\s+gravity\s*\*\s*\(\s*0\.4\s*-", body):
        fail("landing_admit_site missing unvalidated brake factor 0.4")


def main():
    count = check_entry_charts()
    check_kerbin_corridor()
    check_brake_factor()
    read_text(SCRIPT / "Libraries/Poseidon_SSTO/flight_log.ks")
    print(
        f"ok: {count} entry charts (range and energy in metres); "
        "Kerbin deorbit corridor literals present; flight_log.ks readable; "
        "landing_admit_site brake factor 0.4 is an estimate, not a measured result"
    )


if __name__ == "__main__":
    main()
