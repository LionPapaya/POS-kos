"""Verify the generated PNG/coordinate contract, independent of KSP rendering."""
import json
from pathlib import Path
import re
import struct
import unittest

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'Script/Libraries/gui_images/entry_charts'
LIB=ROOT/'Script/Libraries/Poseidon_SSTO'

class EntryChartAssets(unittest.TestCase):
    def test_catalog_matches_exact_asset_bounds(self):
        catalog=json.loads((ASSETS/'catalog.json').read_text(encoding='utf-8'))
        source=(LIB/'entry_chart_catalog.ks').read_text(encoding='utf-8')
        records=re.findall(r'lex\(([^\n]+)\)',source)
        flat=[r for page in catalog for r in page]
        self.assertEqual(len(records),len(flat))
        self.assertEqual(len(catalog),5)
        for row,record in zip(records,flat):
            pairs=re.findall(r'"(\w+)",("[^"]+"|\d+)',row)
            self.assertEqual({k:json.loads(v) for k,v in pairs},record)
            image=ROOT/'Script'/record['image']
            data=image.read_bytes()
            self.assertEqual(data[:8],b'\x89PNG\r\n\x1a\n')
            self.assertEqual(struct.unpack('>II',data[16:24]),(640,280))
            self.assertLess(record['energy_min'],record['energy_max'])
            self.assertLess(record['range_min'],record['range_max'])

    def test_selection_not_in_gui_or_simulation_loops(self):
        gui=(LIB/'return_gui.ks').read_text(encoding='utf-8')
        self.assertNotIn('entry_chart_select(',gui)
        self.assertIn('entry_chart_selection["pages"][page_index]',gui)
        guidance=(LIB/'entry_guid.ks').read_text(encoding='utf-8')
        self.assertIn('if entry_chart_selection["ready"] or not solved_plan["converged"]',guidance)
        self.assertNotIn('reentry_select_entry_charts', (ROOT/'Script/Libraries/lib_aerosim.ks').read_text(encoding='utf-8'))
        self.assertIn('set entry_chart_selection to lex("ready",false,"pages",list()).',guidance)

    def test_logger_columns_and_live_wiring(self):
        logger=(LIB/'flight_log.ks').read_text(encoding='utf-8')
        self.assertIn('flight_log_dap_smoothing_header() to POS_LOG_FLIGHT_FILE.',logger)
        self.assertIn('flight_log_dap_smoothing_columns() to POS_LOG_FLIGHT_FILE.',logger)
        self.assertIn('global POS_LOG_SCHEMA_VERSION is 40.',logger)
        control=(LIB/'control.ks').read_text(encoding='utf-8')
        self.assertIn('dap_protection_handoff(true).',control)
        self.assertIn('dap_protection_handoff(false).',control)
        self.assertIn('set dap["aoa"]["base_pitch_override"] to false.',control)
        self.assertIn('set dap["aoa"]["base_pitch_override"] to true.',(LIB/'terminal_route.ks').read_text(encoding='utf-8'))

if __name__=='__main__':
    unittest.main()
