#!/usr/bin/env python3
"""Check a branded tree against the original: identity, profile dir, icons, strings, translations."""
import glob, os, re, subprocess, sys

branded, original = sys.argv[1], sys.argv[2]
fail = []
def check(cond, msg):
    print(('ok   ' if cond else 'FAIL ') + msg)
    if not cond: fail.append(msg)

t = 'chrome/app/theme/chromium'
b = open(os.path.join(branded, t, 'BRANDING')).read()
check('PRODUCT_FULLNAME=Drift' in b and 'MAC_BUNDLE_ID=dev.drift.Drift' in b, 'BRANDING has Drift name and bundle id')
check('"Drift Browser"' in open(os.path.join(branded, 'chrome/common/chrome_paths_mac.mm')).read(), 'profile folder is "Drift Browser"')
skip_car = os.environ.get('DRIFT_SKIP_ACTOOL') == '1'
for f in ['mac/app.icns'] + ([] if skip_car else ['mac/Assets.car']) + ['product_logo_256.png', 'product_logo_16.png', 'product_logo.svg']:
    p, o = os.path.join(branded, t, f), os.path.join(original, t, f)
    check(os.path.getsize(p) > 0 and open(p, 'rb').read() != open(o, 'rb').read(), f'{f} replaced')
if sys.platform == 'darwin' and os.environ.get('DRIFT_SKIP_ACTOOL') != '1':
    info = subprocess.run(['xcrun', 'assetutil', '--info', os.path.join(branded, t, 'mac/Assets.car')], capture_output=True, text=True)
    check(info.returncode == 0 and 'AppIcon' in info.stdout, 'Assets.car contains an AppIcon')

grd = open(os.path.join(branded, 'chrome/app/chromium_strings.grd'), encoding='utf-8').read()
check(grd.count('Drift') > 500, f'product name rebranded in strings ({grd.count("Drift")} mentions)')
check('The Chromium Authors' in grd, 'legal attribution "The Chromium Authors" kept')

def ids(src):
    sys.path.insert(0, os.path.join(src, 'tools', 'grit'))
    for k in [k for k in sys.modules if k == 'grit' or k.startswith('grit.')]: del sys.modules[k]
    from grit import grd_reader
    from grit.node import message
    root = grd_reader.Parse(os.path.join(src, 'chrome/app/chromium_strings.grd'), dir=os.path.join(src, 'chrome/app'),
                            first_ids_file=None, skip_validation_checks=True)
    sys.path.pop(0)
    return {n.GetCliques()[0].GetMessage().GetId() for n in root.GetChildrenOfType(message.MessageNode)}
oi, ni = ids(original), ids(branded)
lost = 0
for f in glob.glob(os.path.join(original, 'chrome/app/resources/chromium_strings_*.xtb')):
    n = os.path.join(branded, 'chrome/app/resources', os.path.basename(f))
    ot = set(re.findall(r'<translation id="(\d+)"', open(f, encoding='utf-8').read()))
    nt = set(re.findall(r'<translation id="(\d+)"', open(n, encoding='utf-8').read()))
    lost = max(lost, len(ot & oi) - len(nt & ni))
check(lost == 0, f'every translation still matches its message (max lost per language: {lost})')

sys.exit(1 if fail else 0)
