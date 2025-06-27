#! /usr/bin/env bash


TUTORIALS=$(python -c "print(__import__('marimo').__path__.pop())")

cd "$(dirname "$0")"/../tutorials

for py in "$TUTORIALS"/_tutorials/*.py; do
  # 어째서인지 리터럴 *.py가 글로브될 수 있습니다.
  if [ "$py" == '*.py' ]; then
    continue
  fi
  # 숨겨진 경우는 무시합니다.
  if [[ $py != *_tutorials/_* ]]; then
    echo $py
    marimo export md "$py" -o "$(basename "$py" .py).qmd"
  fi
done

for md in "$TUTORIALS"/_tutorials/*.md; do
  # 어째서인지 리터럴 *.md가 글로브될 수 있습니다.
  if [ "$md" == '*.md' ] || [ $(basename "$md") == "README.md" ]; then
    continue
  fi
  # 숨겨진 경우는 무시합니다.
  if [[ $md != *_tutorials/_* ]]; then
    echo $md
    marimo export md "$md" -o "$(basename "$md" .md).qmd"
  fi
done

cd -
