# marimo + quarto = :palm_tree: :heart:

> [!WARNING]
> The Quarto marimo plugin is under active development. Features and documentation are being continuously updated and expanded.

## marimo

marimo is a next generation python notebook that is embeddable anywhere.
As such, it is a great fit for quarto, which has reactive and robust a publishing system.
This repo is a quarto filter that lets you use marimo in your quarto documents; just follow the setup below.

### Quick Start

**1.** Tool Installation

 - Install [uv](https://docs.astral.sh/uv/getting-started/installation/)
 - Install [Quarto](https://quarto.org/docs/get-started/) (if you have brew: `brew install quarto`)

**2.** Create a project

```bash
quarto create project
```

**3.** Add `quarto-marimo` to your project

```bash
quarto add marimo-team/quarto-marimo
```

**4.** Edit your `index.qmd`

````yaml
---
filters:
    - marimo-team/marimo
---

# Just another Quarto project

```python {.marimo}
#| echo: true
import marimo as mo
mo.md("Hello World!")
```
````

**5.** Run!

```bash
quarto-cli preview
# uvx --with marimo --from quarto-cli quarto preview
```

### Features

This plugin uses [`marimo
islands`](https://docs.marimo.io/guides/exporting/?h=islands#islands-in-action)
:palm_tree: which allows marimo content to be embedded in between other
content. In addition to base marimo support, some [Quarto execution
options](https://quarto.org/docs/computations/execution-options.html) are also
supported:

| Option | Default | Description |
|--------|---------|-------------|
eval | True | Whether this code should run
echo | False | Whether to show the code in the output
output | True | Whether to show the output
warning | True | Whether to show warnings
error | True | Whether to show errors
include | True | Whether to consider the block as part of the document
editor | False | Whether to show the editor (only for marimo)

:bulb: **Note**: You can open `.md` and `.qmd` files directly in marimo
like a normal notebook. Read more about it in the
[tutorial](https://github.com/marimo-team/marimo/blob/main/marimo/_tutorials/markdown_format.md)

:notebook: [**Check out the marimo mkdocs
extension**](https://github.com/marimo-team/mkdocs-marimo)

---

Credits: [holoviz-quarto](https://github.com/awesome-panel/holoviz-quarto) for ideas on layout
