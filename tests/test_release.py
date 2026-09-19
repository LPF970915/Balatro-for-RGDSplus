import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("release", ROOT / "tools/build_release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseTests(unittest.TestCase):
    def test_reviewed_adapter(self):
        files, _ = release.verify_adapter()
        self.assertIn(release.ENTRY, files)
        self.assertNotIn(release.APP + "gamedata/Balatro.exe", files)

    def test_path_rejection(self):
        for path in ("../game.lua", "/game.lua", "C:/game.lua", "a\\b.lua", "a//b.lua",
                     "Ports/game.love", "Ports/GAME.EXE", "Ports/game.zip",
                     "Ports/cache/main.lua", "Ports/saves/profile.jkr",
                     "Ports/logs/latest.txt", "Ports/BalatroDual/gamedata/data.bin",
                     "README.md", "Ports/extra.txt", "Other/game.lua"):
            self.assertFalse(release.allowed_name(path), path)
        self.assertTrue(release.allowed_name(release.GAME_DATA_NOTICE))

    def test_modified_file_and_extra_file_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copytree(ROOT / "adapter", root / "adapter")
            shutil.copytree(ROOT / "metadata", root / "metadata")
            file = root / "adapter" / release.ENTRY
            original = file.read_bytes()
            file.write_bytes(original + b"\n# changed\n")
            with self.assertRaises(ValueError):
                release.verify_adapter(root)
            file.write_bytes(original)
            extra = root / "adapter/Ports/extra.txt"
            extra.write_text("unreviewed")
            with self.assertRaises(ValueError):
                release.verify_adapter(root)
            extra.unlink()
            (root / "adapter" / release.GAME_DATA_NOTICE).unlink()
            with self.assertRaises(ValueError):
                release.verify_adapter(root)

    def test_archive_is_reproducible(self):
        out = release.build()
        self.assertEqual(out.name, "Balatro for RGDSplus.zip")
        with zipfile.ZipFile(out) as archive:
            self.assertEqual({n.split("/")[0] for n in archive.namelist()}, {"Ports"})
            self.assertEqual({n.split("/")[1] for n in archive.namelist() if n != "Ports/"},
                             {"BalatroDual", "Balatro for RGDSplus.sh"})
        before = out.read_bytes()
        release.build()
        self.assertEqual(before, out.read_bytes())


if __name__ == "__main__":
    unittest.main()
