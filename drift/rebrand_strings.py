#!/usr/bin/env python3
"""Rename the product in Chromium's user-visible strings ("Chromium" -> "Drift").

Translations (.xtb) are keyed by a fingerprint of each English message, so
editing the English text alone would orphan every translation. This script uses
Chromium's own `grit` to compute each message's id before and after the
substitution, then rewrites the .xtb files with the new ids and substituted text.

Kept as-is on purpose: the legal attribution ("The Chromium Authors"),
"ChromiumOS"/"Chromium OS", and lowercase URLs (chromium.org).

Usage: rebrand_strings.py <chromium src dir> [--name Drift]
"""
import argparse
import glob
import os
import re
import sys

# Word "Chromium", but not when it is part of names that must stay.
PATTERN = re.compile(r'\bChromium\b(?!\s*(?:Authors\b|OS\b|Projects?\b))')

GRD = 'chrome/app/chromium_strings.grd'
PARTS = ['chrome/app/settings_chromium_strings.grdp']
XTB_GLOB = 'chrome/app/resources/chromium_strings_*.xtb'


def message_ids(src, grd_path):
    """Grit message ids for every <message> in the grd (and its parts), in document order.

    Names are not unique (platform variants share a name inside <if> blocks), so
    callers pair messages by position; substitution never changes the structure."""
    sys.path.insert(0, os.path.join(src, 'tools', 'grit'))
    from grit import grd_reader  # pylint: disable=import-outside-toplevel
    from grit.node import message  # pylint: disable=import-outside-toplevel
    root = grd_reader.Parse(grd_path, dir=os.path.dirname(grd_path), first_ids_file=None, skip_validation_checks=True)
    return [(node.attrs['name'], node.GetCliques()[0].GetMessage().GetId())
            for node in root.GetChildrenOfType(message.MessageNode)]


def substitute(text, name):
    return PATTERN.sub(name, text)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('src')
    ap.add_argument('--name', default='Drift')
    args = ap.parse_args()
    src = os.path.abspath(args.src)
    grd = os.path.join(src, GRD)

    old_ids = message_ids(src, grd)

    changed = 0
    for rel in [GRD] + PARTS:
        path = os.path.join(src, rel)
        before = open(path, encoding='utf-8').read()
        after = substitute(before, args.name)
        changed += before != after
        open(path, 'w', encoding='utf-8').write(after)

    new_ids = message_ids(src, grd)
    if [n for n, _ in old_ids] != [n for n, _ in new_ids]:
        sys.exit('rebrand_strings: message structure changed unexpectedly')
    remap = {o: n for (_, o), (_, n) in zip(old_ids, new_ids) if o != n}

    id_re = re.compile(r'(<translation id=")(\d+)(")')
    xtbs = sorted(glob.glob(os.path.join(src, XTB_GLOB)))
    for path in xtbs:
        text = open(path, encoding='utf-8').read()
        text = id_re.sub(lambda m: m.group(1) + remap.get(m.group(2), m.group(2)) + m.group(3), text)
        text = substitute(text, args.name)
        open(path, 'w', encoding='utf-8').write(text)

    print(f'rebrand_strings: {len(old_ids)} messages, {len(remap)} ids remapped, {len(xtbs)} translation files, '
          f'{changed} source files changed')


if __name__ == '__main__':
    main()
