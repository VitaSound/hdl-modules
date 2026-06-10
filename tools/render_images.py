#!/usr/bin/env python3
"""Render waveform PNG images via GTKWave window grab."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
EXPORT_TCL = ROOT / "tools" / "export_wave.tcl"
GTKWAVERC = ROOT / "tools" / "gtkwaverc.render"
XVFB_SCREEN = "1600x900x24"


def load_modules() -> list[dict]:
    with (ROOT / "modules.yaml").open(encoding="utf-8") as fh:
        data = yaml.safe_load(fh)

    modules: list[dict] = []
    for category in data["categories"]:
        if category["id"] == "common":
            modules.extend(category["modules"])
        elif category["id"] == "generation":
            modules.extend(category["packages"])
    return modules


def require_tool(name: str) -> None:
    if shutil.which(name) is None:
        raise RuntimeError(f"Required tool not found: {name}")


def postprocess_png(path: Path) -> None:
    try:
        from PIL import Image, ImageChops
    except ImportError:
        return

    img = Image.open(path).convert("RGB")
    bg = Image.new("RGB", img.size, img.getpixel((0, 0)))
    bbox = ImageChops.difference(img, bg).getbbox()
    if bbox:
        img = img.crop(bbox)
    img.save(path, optimize=True)


def render_module(module: dict, root: Path) -> None:
    module_id = module["id"]
    test_dir = root / module["test_dir"]
    vcd = test_dir / "out.vcd"
    image = root / module["image"]
    gtkw = root / module["gtkw"] if module.get("gtkw") else None

    if not vcd.is_file():
        raise FileNotFoundError(f"{module_id}: missing {vcd}, run tests first")

    with tempfile.NamedTemporaryFile(suffix=".png", dir=test_dir, delete=False) as tmp:
        tmp_png = Path(tmp.name)

    env = os.environ.copy()
    env["WAVE_PNG_FILE"] = str(tmp_png)
    if gtkw and gtkw.is_file():
        env["GTKW_FILE"] = str(gtkw)
    else:
        env.pop("GTKW_FILE", None)

    cmd = [
        "xvfb-run",
        "-s",
        f"-screen 0 {XVFB_SCREEN}",
        "-a",
        "gtkwave",
        "-M",
        "-r",
        str(GTKWAVERC),
    ]
    if gtkw and gtkw.is_file():
        cmd.extend([str(vcd.name), str(gtkw.name)])
    else:
        cmd.append(str(vcd.name))
    cmd.extend(["--script", str(EXPORT_TCL)])

    print(f"[image] {module_id}: grabbing GTKWave window")
    try:
        subprocess.run(cmd, cwd=test_dir, env=env, check=True)
    finally:
        if not tmp_png.is_file():
            tmp_png.unlink(missing_ok=True)
            raise FileNotFoundError(f"{module_id}: PNG grab was not created")

        image.parent.mkdir(parents=True, exist_ok=True)
        postprocess_png(tmp_png)
        tmp_png.replace(image)
        print(f"[image] {module_id}: saved {image.relative_to(root)}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--id", help="Render a single module by id")
    args = parser.parse_args()

    for tool in ("xvfb-run", "gtkwave"):
        require_tool(tool)

    modules = load_modules()
    if args.id:
        modules = [m for m in modules if m["id"] == args.id]
        if not modules:
            print(f"Unknown module id: {args.id}", file=sys.stderr)
            return 1

    failed = 0
    for module in modules:
        try:
            render_module(module, ROOT)
        except (subprocess.CalledProcessError, FileNotFoundError, RuntimeError) as exc:
            print(f"[image] {module['id']}: FAILED - {exc}", file=sys.stderr)
            failed += 1

    if failed:
        print(f"\n{failed} image render(s) failed", file=sys.stderr)
        return 1

    print(f"\nRendered {len(modules)} image(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
