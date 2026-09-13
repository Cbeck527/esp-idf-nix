#!/usr/bin/env bash
set -euo pipefail

python - <<'PY'
import struct
import shutil
import subprocess
from pathlib import Path

for compiler in ("xtensa-esp-elf", "riscv32-esp-elf"):
    gcc = shutil.which(f"{compiler}-gcc")
    assert gcc is not None, f"missing {compiler}-gcc"
    gcc_path = Path(gcc).resolve()
    root = gcc_path.parent.parent
    archives = sorted(root.rglob("libgcc.a"))
    assert archives, f"no {compiler} libgcc.a archives found"
    for archive in archives:
        data = archive.read_bytes()
        assert data.startswith(b"!<arch>\n"), archive
        header = data[8:68]
        assert len(header) == 60 and header[-2:] == b"`\n", archive
        name = header[:16].decode("ascii").strip()
        assert name == "/", f"{archive}: first member is {name!r}, no GNU index"
        size = int(header[48:58].decode("ascii").strip())
        index = data[68:68 + size]
        assert len(index) >= 4, archive
        count = struct.unpack(">I", index[:4])[0]
        assert count > 0, f"{archive}: empty GNU archive index"
        print(f"{compiler}: {archive} archive index count={count}")
        if compiler == "riscv32-esp-elf":
            symbols = subprocess.run(
                ["riscv32-esp-elf-nm", "-s", str(archive)],
                text=True, capture_output=True, check=True,
            ).stdout
            assert "__trunctfdf2 in " in symbols, archive
PY

probe="$TMPDIR/trunctfdf2.c"
probe_elf="$TMPDIR/trunctfdf2.elf"
cat >"$probe" <<'EOF'
extern double __trunctfdf2(long double);
double probe(long double value) { return __trunctfdf2(value); }
EOF
riscv32-esp-elf-gcc -march=rv32imc -mabi=ilp32 -nostdlib \
  -Wl,-e,probe "$probe" -o "$probe_elf" -lgcc
test -z "$(riscv32-esp-elf-nm -u "$probe_elf")" || {
  echo "minimal RISC-V link left undefined symbols" >&2
  exit 1
}
