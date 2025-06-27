# marimo + Quarto = 🌴 ❤️

## marimo

**marimo**는 어디든 삽입할 수 있는 차세대 파이썬 노트북입니다.
따라서, 반응형이면서도 강력한 퍼블리싱 시스템을 갖춘 Quarto와 아주 잘 어울립니다.
이 저장소는 Quarto 문서에서 marimo를 사용할 수 있게 해주는 Quarto 필터입니다. 아래 설정 지침을 따라주세요.

### 빠른 시작

**1. 도구 설치**

  * [uv](https://docs.astral.sh/uv/getting-started/installation/) 설치
  * [Quarto](https://quarto.org/docs/get-started/) 설치 (brew가 있다면: `brew install quarto`)

**2. 프로젝트 생성**

```bash
quarto create project
```

**3. 프로젝트에 `quarto-marimo` 추가**

```bash
quarto add marimo-team/quarto-marimo
```

**4. `index.qmd` 파일 편집**

````yaml
---
filters:
  - marimo-team/marimo
---

# 흔한 Quarto 프로젝트

```python {.marimo}
#| echo: true
import marimo as mo
slider = mo.ui.slider(1, 10, 1, label="짜잔, 슬라이더!")
slider
```

## 추가 내용

이제 응답할 수 있어요!

```python {.marimo}
# 여기에 echo가 없으면 코드를 출력하지 않습니다.
mo.md("NaN" * slider.value + " Batman!")
```
````

**5. 실행\!**

```bash
quarto preview
# uvx --with marimo --from quarto-cli quarto preview
```


### 기능

이 플러그인은 **marimo Islands** 🌴를 사용합니다. 이를 통해 marimo 콘텐츠를 다른 콘텐츠 사이에 삽입할 수 있습니다. 기본 marimo 지원 외에도 일부 [Quarto 실행 옵션](https://quarto.org/docs/computations/execution-options.html)도 지원됩니다:

| 옵션    | 기본값 | 설명                           |
|---------|--------|--------------------------------|
| eval    | True   | 이 코드를 실행할지 여부        |
| echo    | False  | 코드를 출력에 표시할지 여부    |
| output  | True   | 출력을 표시할지 여부           |
| warning | True   | 경고를 표시할지 여부           |
| error   | True   | 오류를 표시할지 여부           |
| include | True   | 블록을 문서의 일부로 간주할지 여부 |
| editor  | False  | 에디터를 표시할지 여부 (marimo 전용) |

💡 **참고**: `.md` 및 `.qmd` 파일을 일반 노트북처럼 marimo에서 직접 열 수 있습니다. 자세한 내용은 [튜토리얼](https://github.com/marimo-team/marimo/blob/main/marimo/_tutorials/markdown_format.md)에서 확인하세요.


### 환경

기본적으로 marimo는 `uv`를 사용하여 새로운 가상 환경을 생성합니다.
[문서](https://docs.marimo.io/guides/package_reproducibility#markdown-file-support)를 따라 노트북 YAML 파일에 `pyproject` 값을 설정하여 의존성을 지정할 수 있습니다.

샌드박스 동작을 비활성화하려면 노트북 YAML 파일에 `external-env: true`를 설정하세요. 이 경우 marimo가 설치된 활성 가상 환경이 필요합니다.

> [\!NOTE]
> `pyproject` 또는 `external-env`를 `_quarto.yml` 파일에 추가하여 전역적으로 적용할 수 있습니다.

참고로, 로컬 파일은 WASM 런타임에서 접근할 수 없습니다. 또한 웹 로드 시 의존성은 [`micropip`](https://github.com/pyodide/micropip)을 통해 설치됩니다.
따라서 이 기능은 주로 PDF 렌더링 또는 JavaScript를 지원하지 않는 다른 출력 형식에 권장됩니다.

---

크레딧: 레이아웃 아이디어에 대한 [holoviz-quarto](https://github.com/awesome-panel/holoviz-quarto)에 감사드립니다.
