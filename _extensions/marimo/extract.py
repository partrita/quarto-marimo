#!/usr/bin/env python3

import asyncio
import json
import os
import re
import sys
from typing import Any, Callable, Optional

# Native to python # 파이썬 기본 내장
from xml.etree.ElementTree import Element

import marimo
from marimo import MarimoIslandGenerator

try:
    from marimo._ast.app import App
    from marimo._convert.markdown.markdown import (
        MARIMO_MD,
        MarimoMdParser as MarimoParser,
        SafeWrap as SafeWrapGeneric,
    )

    SafeWrap = SafeWrapGeneric[App]
except ImportError:
    # Fallback for marimo < 0.13.16 # marimo < 0.13.16 버전을 위한 대체 코드
    from marimo._cli.convert.markdown import (  # type: ignore[import, no-redef] # 타입: 무시[import, 재정의 없음]
        MARIMO_MD,
        MarimoParser,
        SafeWrap,
    )

from marimo._islands import MarimoIslandStub

__version__ = "0.0.1"

# See https://quarto.org/docs/computations/execution-options.html # https://quarto.org/docs/computations/execution-options.html 참조
default_config = {
    "eval": True,
    "echo": False,
    "output": True,
    "warning": True,
    "error": True,
    "include": True,
    # Particular to marimo # marimo 특정
    "editor": False,
}


def extract_and_strip_quarto_config(block: str) -> tuple[dict[str, Any], str]:
    pattern = r"^\s*\#\|\s*(.*?)\s*:\s*(.*?)(?=\n|\Z)"
    config: dict[str, Any] = {}
    lines = block.split("\n")
    if not lines:
        return config, block

    split_index = 0
    for i, line in enumerate(lines):
        split_index = i
        line = line.strip()
        if not line:
            continue
        source_match = re.search(pattern, line)
        if not source_match:
            break
        key, value = source_match.groups()
        config[key] = json.loads(value)
    return config, "\n".join(lines[split_index:])


def get_mime_render(
    global_options: dict[str, Any],
    stub: Optional[MarimoIslandStub],
    config: dict[str, bool],
    mime_sensitive: bool,
) -> dict[str, Any]:
    # Local supersede global supersedes default options # 로컬 > 전역 > 기본 옵션 순으로 적용
    config = {**global_options, **config}
    if not config["include"] or stub is None:
        return {"type": "html", "value": ""}

    output = stub.output
    render_options = {
        "display_code": config["echo"],
        "reactive": config["eval"] and not mime_sensitive,
        "code": stub.code,
    }

    if output:
        mimetype = output.mimetype
        if config["output"] and mime_sensitive:
            if mimetype.startswith("image"):
                return {"type": "figure", "value": f"{output.data}", **render_options}
            if mimetype.startswith("text/plain") or mimetype.startswith(
                "text/markdown"
            ):
                return {"type": "para", "value": f"{output.data}", **render_options}
            if mimetype == "application/vnd.marimo+error":
                if config["error"]:
                    return {
                        "type": "blockquote",
                        "value": f"{output.data}",
                        **render_options,
                    }
                # Suppress errors otherwise # 그렇지 않으면 오류 숨김
                return {"type": "para", "value": "", **render_options}

        elif mimetype == "application/vnd.marimo+error":
            if config["warning"]:
                sys.stderr.write(
                    "Warning: Only the `disabled` codeblock attribute is utilized" # 경고: pandoc 내보내기에는 `disabled` 코드 블록 속성만 사용됩니다.
                    " for pandoc export. Be sure to set desired code attributes " # quarto 형식으로 원하는 코드 속성을 설정해야 합니다.
                    "in quarto form."
                )
            if not config["error"]:
                return {"type": "html", "value": ""}

    # HTML as catch all default # 모든 경우에 대한 기본값으로 HTML 사용
    return {
        "type": "html",
        "value": stub.render(
            display_code=config["echo"],
            display_output=config["output"],
            is_reactive=bool(render_options["reactive"]),
            as_raw=mime_sensitive,
        ),
        **render_options,
    }


def app_config_from_root(root: Element) -> dict[str, Any]:
    # Extract meta data from root attributes. # 루트 속성에서 메타 데이터 추출
    config_keys = {"title": "app_title", "marimo-layout": "layout_file"}
    config = {
        config_keys[key]: value for key, value in root.items() if key in config_keys
    }
    # Try to pass on other attributes as is # 다른 속성들은 그대로 전달 시도
    config.update({k: v for k, v in root.items() if k not in config_keys})
    # Remove values particular to markdown saves. # 마크다운 저장에 특화된 값 제거
    config.pop("marimo-version", None)
    return config


def build_export_with_mime_context(
    mime_sensitive: bool,
) -> Callable[[Element], SafeWrap]:
    def tree_to_pandoc_export(root: Element) -> SafeWrap:
        global_options = {**default_config, **app_config_from_root(root)}
        app = MarimoIslandGenerator()

        has_attrs: bool = False
        stubs: list[tuple[dict[str, bool], Optional[MarimoIslandStub]]] = []
        for child in root:
            # only process code cells # 코드 셀만 처리
            if child.tag == MARIMO_MD:
                continue
            # We only care about the disabled attribute. # disabled 속성만 중요하게 생각합니다.
            if child.attrib.get("disabled") == "true":
                # Don't even add to generator # 생성기에 추가하지 않음
                stubs.append(({"include": False}, None))
                continue
            # Check to see id attrs are defined on the tag # 태그에 id 속성이 정의되어 있는지 확인
            has_attrs = has_attrs | bool(child.attrib.items())

            code = str(child.text)
            config, code = extract_and_strip_quarto_config(code)

            try:
                stub = app.add_code(
                    code,
                    is_raw=True,
                )
            except Exception:
                stubs.append((config, None))
                continue

            assert isinstance(stub, MarimoIslandStub), "Unexpected error, please report" # 예상치 못한 오류입니다. 신고해주세요.

            stubs.append(
                (
                    config,
                    stub,
                )
            )

        if has_attrs and global_options.get("warning", True):
            pass

        _ = asyncio.run(app.build())
        dev_server = os.environ.get("QUARTO_MARIMO_DEBUG_ENDPOINT", False)
        version_override = os.environ.get("QUARTO_MARIMO_VERSION", marimo.__version__)
        header = app.render_head(
            _development_url=dev_server, version_override=version_override
        )

        return SafeWrap(
            {
                "header": header,
                "outputs": [
                    get_mime_render(global_options, stub, config, mime_sensitive)
                    for config, stub in stubs
                ],
                "count": len(stubs),
            }  # type: ignore[arg-type] # 타입: 무시[인수-타입]
        )

    return tree_to_pandoc_export


class MarimoPandocParser(MarimoParser):
    """Parses Markdown to marimo notebook string.""" # 마크다운을 marimo 노트북 문자열로 파싱합니다.

    # TODO: Could upstream generic for keys- but this is fine. # TODO: 키에 대한 제네릭을 업스트림할 수 있지만, 이대로도 괜찮습니다.
    output_formats = {  # type: ignore[assignment, misc] # 타입: 무시[할당, 기타]
        "marimo-pandoc-export": build_export_with_mime_context(mime_sensitive=False),  # type: ignore[dict-item] # 타입: 무시[사전-항목]
        "marimo-pandoc-export-with-mime": build_export_with_mime_context(
            mime_sensitive=True
        ),  # type: ignore[dict-item] # 타입: 무시[사전-항목]
    }


def convert_from_md_to_pandoc_export(text: str, mime_sensitive: bool) -> dict[str, Any]:
    if not text:
        return {"header": "", "outputs": []}
    if mime_sensitive:
        parser = MarimoPandocParser(output_format="marimo-pandoc-export-with-mime")  # type: ignore[arg-type] # 타입: 무시[인수-타입]
    else:
        parser = MarimoPandocParser(output_format="marimo-pandoc-export")  # type: ignore[arg-type] # 타입: 무시[인수-타입]
    return parser.convert(text)  # type: ignore[arg-type, return-value] # 타입: 무시[인수-타입, 반환-값]


if __name__ == "__main__":
    assert len(sys.argv) == 3, f"Unexpected call format got {sys.argv}" # 예상치 못한 호출 형식입니다. {sys.argv}를 받았습니다.
    _, reference_file, mime_sensitive = sys.argv

    file = sys.stdin.read()
    if not file:
        with open(reference_file) as f:
            file = f.read()
    no_js = mime_sensitive.lower() == "yes"
    os.environ["MARIMO_NO_JS"] = str(no_js).lower()

    conversion = convert_from_md_to_pandoc_export(file, no_js)
    sys.stdout.write(json.dumps(conversion))
