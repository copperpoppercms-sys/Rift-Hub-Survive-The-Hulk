from pathlib import Path
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
luau = os.environ.get("LUAU_BIN") or shutil.which("luau")
compiler = os.environ.get("LUAU_COMPILE_BIN") or shutil.which("luau-compile")
if not luau or not compiler:
    raise SystemExit("Set LUAU_BIN and LUAU_COMPILE_BIN to native Luau executables.")
source = (root / "main.lua").read_text()
subprocess.run([compiler, "--null", str(root / "main.lua")], check=True)
fixture = (root / "tests/mock_prefix.luau").read_text()
fixture += (root / "tests/checks.luau").read_text().replace("-- INSERT HULK SCRIPT", source)
with tempfile.NamedTemporaryFile(mode="w", suffix=".luau") as f:
    f.write(fixture)
    f.flush()
    subprocess.run([luau, f.name], check=True)
