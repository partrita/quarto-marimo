#!/usr/bin/env python3

import json
import sys
import tempfile
from textwrap import dedent

from marimo._cli.sandbox import PyProjectReader, construct_uv_flags


def extract_command(header: str) -> list[str]:
    if not header.startswith("#"):
        header = "\n# ".join(["# /// script", *header.splitlines(), "///"])
    pyproject = PyProjectReader.from_script(header)
    with tempfile.NamedTemporaryFile(
        mode="w", delete=False, suffix=".txt"
    ) as temp_file:
        flags = construct_uv_flags(pyproject, temp_file, [], [])

    return ["run"] + flags


if __name__ == "__main__":
    assert len(sys.argv) == 1, f"Unexpected call format got {sys.argv}"

    header = dedent(sys.stdin.read())

    command = extract_command(header)
    sys.stdout.write(json.dumps(command))
