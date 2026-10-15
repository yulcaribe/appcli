"""GCC compile tests of the OEM net_device_stats layout sentinel."""
from pathlib import Path
import subprocess
import tempfile
import unittest
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from port import GUARD

class AbiGuardTests(unittest.TestCase):
    def compile_with_stats_size(self, size):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "linux").mkdir()
            (root / "linux/netdevice.h").write_text(
                "struct net_device_stats { char raw[%d]; };\n" % size)
            (root / "h298_oem_abi_guard.h").write_text(GUARD)
            (root / "test.c").write_text('#include "h298_oem_abi_guard.h"\n')
            # GCC host is usually 64-bit: replace the separate 32-bit pointer
            # sentinel for this stats-only fixture; keep the real source intact.
            guard_file = root / "h298_oem_abi_guard.h"
            guard_file.write_text(GUARD.replace(
                "typedef char h298_pointer_width[sizeof(void *) == 4 ? 1 : -1];", ""))
            return subprocess.run(
                ["gcc", "-std=c89", "-fsyntax-only", "-I", str(root),
                 str(root / "test.c")],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE).returncode

    def test_matching_112_byte_stats_compiles(self):
        self.assertEqual(self.compile_with_stats_size(112), 0)

    def test_generic_92_byte_stats_fails(self):
        self.assertNotEqual(self.compile_with_stats_size(92), 0)

if __name__ == "__main__":
    unittest.main()
