#!/usr/bin/env python3
from pathlib import Path
import json, re
root = Path(__file__).resolve().parents[1]
catalog = json.loads((root/'SpaceMithra/Localization/Localizable.xcstrings').read_text())
locales = ['en','si','ta','hi','ar','fr','zh-Hans']
for key,entry in catalog['strings'].items():
    for locale in locales:
        assert entry['localizations'][locale]['stringUnit']['value'].strip(), (key,locale)
for family,values in {
    'recoveryCheck.':['available','missing','changed','conflict','unverified','notApplicable'],
    'state.':['idle','preparing','scanning','paused','completed','cancelled','failed'],
    'riskLevel.':['low','reviewRequired','protected','unknown'],
    'history.':['pending','trashed','skipped','uncertain','restoring','restored','cancelled'],
    'bucket.':['applications','images','videos','documents','downloads','caches','developer','other'],
    'bucket.explain.':['applications','images','videos','documents','downloads','caches','developer','other'],
    'suggestion.':['installers','videos','caches'],
    'suggestion.explain.':['installers','videos','caches'],
    'category.':['applications','documents','images','videos','audio','archives','installers','caches','logs','backups','developer','support','cloud','unknown'],
}.items():
    for value in values: assert family+value in catalog['strings']
for source in (root/'SpaceMithra').rglob('*.swift'):
    for key in re.findall(r'(?:text|field)\("([^"\n]+)"\s*[,)]', source.read_text()):
        if not key.endswith('.'):
            assert key in catalog['strings'], (source,key)
print(f"PASS: {len(catalog['strings'])} keys × {len(locales)} locales, all dynamic families present")

for locale in locales[1:]:
    pending=[key for key,entry in catalog['strings'].items() if entry['localizations'][locale]['stringUnit']['state'] != 'translated']
    print(f"REVIEW REQUIRED: {locale}: {len(pending)} draft or untranslated keys (presence is not linguistic approval)")
