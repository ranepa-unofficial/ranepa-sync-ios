#!/usr/bin/env python3
"""Правка update.json для одного канала.

    python3 -I scripts/update_json.py testflight VERSION BUILD [NOTES]
    python3 -I scripts/update_json.py appstore   VERSION [NOTES]

Меняет только latest (+ latestBuild) и notes; minimum поднимают вручную.
Код выхода 1 — ничего не изменилось (версия уже не ниже указанной).
"""
import json
import pathlib
import sys

PATH = pathlib.Path(__file__).resolve().parents[1] / "update.json"


def key(version, build=0):
    return tuple(int(x) for x in version.split(".")), int(build)


def main(argv):
    if len(argv) < 2 or argv[0] not in ("testflight", "appstore"):
        sys.exit(__doc__)
    channel, version, rest = argv[0], argv[1], argv[2:]
    data = json.loads(PATH.read_text())
    entry = data[channel]
    if channel == "testflight":
        build, rest = int(rest[0]), rest[1:]
        if key(version, build) <= key(entry["latest"], entry.get("latestBuild", 0)):
            sys.exit(1)
        entry["latest"], entry["latestBuild"] = version, build
    else:
        if key(version) <= key(entry["latest"]):
            sys.exit(1)
        entry["latest"] = version
    notes = " ".join(rest).strip()
    if notes:
        entry["notes"] = notes
    PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main(sys.argv[1:])
