"""Offline safety/coverage checks. These do not emulate Unity or execute kOS."""
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / 'Script/Libraries/Poseidon_SSTO'


def code(text):
    return re.sub(r'//[^\n]*|"[^"\n]*"', lambda m: '""' if m[0].startswith('"') else '', text)


def function(text, name):
    # Token-based extraction retaining original source offsets.
    start = re.search(r'(?im)^function\s+' + name + r'\s*\{', text)
    depth = 1
    for token in re.finditer(r'//[^\n]*|"[^"\n]*"|[{}]', text[start.end():]):
        depth += (token[0] == '{') - (token[0] == '}')
        if not depth:
            return text[start.start():start.end() + token.end()]
    raise AssertionError(name)


class GuiHarnessSafety(unittest.TestCase):
    def test_harness_import_allowlist_and_no_control_commands(self):
        source = (ROOT / 'Script/GUI_TEST.ks').read_text(encoding="utf-8")
        for line in source.splitlines():
            self.assertEqual(line.split('//')[0].count('"') % 2, 0, line)
        imports = re.findall(r'(?im)^RUNONCEPATH\("([^"]+)"\)', source)
        self.assertEqual(imports, ['0:/Libraries/Poseidon_SSTO/gui.ks',
                                   '0:/Libraries/Poseidon_SSTO/gui_dialogs.ks'])
        self.assertNotRegex(code(source), r'(?i)\b(runpath|copypath|deletepath|log|lock|stage|reboot|shutdown)\b')
        self.assertNotRegex(code(source), r'(?i)\b(?:sas|rcs|gear|brakes)\s+(?:on|off)\b')
        self.assertIn('if defined dap or defined main_step or defined AVES', source)
        self.assertIn('set main_dap_mode_menu:onchange to {', source)
        self.assertNotIn('create_reentry_display(', code(source))
        self.assertNotIn('update_readouts(', code(source))

    def test_imported_files_have_only_passive_top_level(self):
        for name in ['gui.ks', 'gui_dialogs.ks', 'gui_style.ks', 'ascent_gui.ks',
                     'return_gui.ks', 'ascent_recovery_gui.ks', 'entry_nominal_profile.ks']:
            source = (LIB / name).read_text(encoding="utf-8")
            # Remove full function definitions, including nested callbacks.
            for name in re.findall(r'(?im)^function\s+(\w+)\s*\{', source):
                body = function(source, name)
                source = source.replace(body, '')
            self.assertNotRegex(code(source), r'(?i)\b(lock|runpath|stage|log|set|until|when)\b')
            imports = re.findall(r'RUNONCEPATH\("([^"]+)"\)', source)
            self.assertTrue(all(Path(x).name in {'gui_style.ks', 'ascent_gui.ks',
                'return_gui.ks', 'ascent_recovery_gui.ks', 'entry_nominal_profile.ks'} for x in imports))

    def test_extracted_dialogs_preserve_production_logic(self):
        passive = (LIB / 'gui_dialogs.ks').read_text(encoding="utf-8")
        for filename, names in [('orbital_maneuver.ks', ['pos_om_catalog', 'pos_om_inputs']),
                                ('PDI/pdi_executive.ks', ['vacuum_target_input'])]:
            original = subprocess.check_output(['git', 'show',
                'HEAD:Script/Libraries/Poseidon_SSTO/' + filename], cwd=ROOT).decode()
            current = (LIB / filename).read_text(encoding="utf-8")
            self.assertIn('RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui_dialogs.ks").', current)
            for name in names:
                before = function(original, name)
                after = function(passive, name)
                after = re.sub(r'\s*pos_gui_window_style\([^\n]+\n', '\n', after)
                self.assertEqual(code(before).split(), code(after).split(), name)
                self.assertNotRegex(code(after), r'(?i)\b(lock|runpath|stage|log|flight_log_event|node)\s*\(')

    def test_fixture_covers_ascent_renderer_keys(self):
        source = (LIB / 'ascent_gui.ks').read_text(encoding="utf-8")
        render = '\n'.join(function(source, x) for x in ['ascent_display_update_hero',
            'ascent_display_update_takeoff', 'update_assent_gui'])
        keys = set(re.findall(r'(?:inputs|sample)\["([^"]+)"\]', render)) - {'abort_display'}
        fixture = function((ROOT / 'Script/GUI_TEST.ks').read_text(encoding="utf-8"), 'gui_test_ascent_sample')
        supplied = set(re.findall(r'set sample\["([^"]+)"\]', fixture))
        self.assertFalse(keys - supplied, keys - supplied)

    def test_catalog_and_entry_assets(self):
        catalog = function((LIB / 'gui_dialogs.ks').read_text(encoding="utf-8"), 'pos_om_catalog')
        self.assertEqual(len(re.findall(r'commands:add\(', catalog)), 22)
        for n in range(1, 6):
            self.assertTrue((ROOT / f'Script/Libraries/gui_images/return_entry_{n}.png').is_file())
        for filename in ['gui_style.ks', 'ascent_gui.ks', 'return_gui.ks']:
            for asset in re.findall(r'"(Libraries/gui_images/[^"+]+\.png)"', (LIB / filename).read_text(encoding="utf-8")):
                self.assertTrue((ROOT / 'Script' / asset).is_file(), asset)

    def test_pos_cannot_fall_through_after_exit(self):
        source = (ROOT / 'Script/POS.ks').read_text(encoding="utf-8")
        self.assertRegex(source, r'RUNPATH\("0:/GUI_TEST.ks"\)\.\s*until false \{ wait 1\. \}')


if __name__ == '__main__':
    unittest.main()
