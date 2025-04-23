# marimo + quarto = :island: :heart:

## marimo

marimo is a next generation python notebook that is embeddable anywhere.
As such, it is a great fit for quarto, which has reactive and robust a publishing system.
This repo is a quarto filter that lets you use marimo in your quarto documents; just follow the setup below.

### Setup

1. Install Quarto + UV

```bash
pip install quarto uv
```

2. Create a project

```bash
quarto create project
```

3. Add `quarto-marimo` to your project

```bash
quarto add marimo-team/quarto-marimo
```

4. Add the filter to relevant files

```yaml
---
filters:
    - marimo-team/marimo
---
```

or just

```yaml
---
filters:
    - marimo
---
```

### Deployment

Run

```bash
quarto preview
```
