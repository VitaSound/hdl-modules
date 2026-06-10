#!/usr/bin/env python3
"""Generate README files from modules.yaml."""

from __future__ import annotations

import sys
from pathlib import Path

import yaml
from jinja2 import Environment, FileSystemLoader, select_autoescape

ROOT = Path(__file__).resolve().parent.parent
TEMPLATES = Path(__file__).resolve().parent / "templates"


def load_data() -> dict:
    with (ROOT / "modules.yaml").open(encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def render_template(name: str, **context) -> str:
    env = Environment(
        loader=FileSystemLoader(TEMPLATES),
        autoescape=select_autoescape(enabled_extensions=()),
        trim_blocks=True,
        lstrip_blocks=True,
    )
    env.filters["basename"] = lambda value: Path(value).name
    template = env.get_template(name)
    return template.render(**context) + "\n"


def write_readme(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")
    print(f"[docs] wrote {path.relative_to(ROOT)}")


def main() -> int:
    data = load_data()
    categories = {cat["id"]: cat for cat in data["categories"]}
    common = categories["common"]
    generation = categories["generation"]

    root_content = render_template(
        "root_readme.md.j2",
        repo=data["repo"],
        common=common,
        generation=generation,
    )
    write_readme(ROOT / "README.md", root_content)

    common_modules = []
    for module in common["modules"]:
        item = dict(module)
        item["image_rel"] = f"{Path(module['test_dir']).name}/test.png"
        common_modules.append(item)

    common_content = render_template(
        "category_readme.md.j2",
        title="Common modules",
        subtitle="Модули общего назначения",
        modules=common_modules,
    )
    write_readme(ROOT / common["readme"], common_content)

    for package in generation["packages"]:
        if not package.get("readme"):
            continue
        package_content = render_template(
            "package_readme.md.j2",
            package=package,
        )
        write_readme(ROOT / package["readme"], package_content)

    print("[docs] README generation complete")
    return 0


if __name__ == "__main__":
    sys.exit(main())
