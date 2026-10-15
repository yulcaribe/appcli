import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from port import port

class PortTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.donor = self.root / "donor"
        (self.donor / "ap").mkdir(parents=True)
        (self.donor / "os/linux").mkdir(parents=True)
        (self.donor / "ap/ap_apcli.c").write_text("APCLI")
        (self.donor / "Makefile").write_text("RT28xx_MODE  = STA\nCHIPSET = mt7603u\n")
        (self.donor / "os/linux/config.mk").write_text(
            "HAS_APCLI=n\n"
            "ifneq ($(findstring mt7603e,$(CHIPSET)),)\n"
            "WFLAGS += -DCONFIG_FPGA_MODE\nendif\n"
            "ifneq ($(findstring mt7603u,$(CHIPSET)),)\n"
            "WFLAGS += -DCONFIG_FPGA_MODE\nendif\n")
        (self.donor / "os/linux/rt_linux.c").write_text(
            "#include <linux/rtnetlink.h>\n"
            "alloc_etherdev(privDataSize);\n"
            "sizeof (struct net_device_stats); sizeof (struct net_device_stats);\n")
    def tearDown(self):
        self.tmp.cleanup()
    def test_real_source_modifications(self):
        dst = self.root / "h298"
        port(self.donor, dst)
        self.assertIn("CHIPSET = mt7603e", (dst / "Makefile").read_text())
        cfg = (dst / "os/linux/config.mk").read_text()
        self.assertIn("HAS_APCLI=y", cfg)
        self.assertEqual(cfg.count("WFLAGS += -DCONFIG_FPGA_MODE"), 1)
        body = (dst / "os/linux/rt_linux.c").read_text()
        self.assertIn("alloc_etherdev_mqs(privDataSize, 1, 1)", body)
        self.assertIn("h298_oem_abi_guard.h", body)
        guard = (dst / "os/linux/h298_oem_abi_guard.h").read_text()
        self.assertIn("sizeof(struct net_device_stats) == 112", guard)
    def test_cannot_overwrite_output(self):
        dest = self.root / "already_exists"
        dest.mkdir()
        with self.assertRaises(FileExistsError):
            port(self.donor, dest)

if __name__ == "__main__":
    unittest.main()
