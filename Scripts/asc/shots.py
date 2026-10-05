#!/usr/bin/env python3
"""The shot list from shots.json, for shoot.sh and screenshots.py.

  shots.py <lang>            # the shots, in capture order, with what each shows
  shots.py <lang> --plain    # one per line: name <RS> title <RS> KEY=value<US>… <RS> by-hand note
  shots.py <lang> --store    # names only, in store order

A shot's `stage` (its stage.sh variables) is merged with `stage_<lang>`, so a
language can carry its own pin notes; `{instance}` in a value is the
INSTANCE environment variable, or shots.json's `instance`.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def load():
    return json.load(open(os.path.join(HERE, "shots.json")))


def ordered(order="capture"):
    doc = load()
    return [(name, doc["shots"][name]) for name in doc[order]]


def stage_vars(shot, lang):
    doc = load()
    instance = os.environ.get("INSTANCE") or doc["instance"]
    merged = {**shot.get("stage", {}), **shot.get(f"stage_{lang}", {})}
    return {k: str(v).replace("{instance}", instance) for k, v in merged.items()}


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    lang = sys.argv[1]
    flags = sys.argv[2:]
    if "--store" in flags:
        for name, _ in ordered("store"):
            print(name)
        return
    for name, shot in ordered():
        if "--plain" in flags:
            args = "\x1f".join(f"{k}={v}" for k, v in stage_vars(shot, lang).items())
            print("\x1e".join([name, shot["title"], args, shot.get("by_hand", "")]))
        else:
            print(f"{name}: {shot['title']}\n  {shot['about']}")


if __name__ == "__main__":
    main()
