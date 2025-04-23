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
