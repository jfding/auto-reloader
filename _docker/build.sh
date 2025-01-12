#!/bin/sh

cd ../gh-webhook/
uv build
cp dist/*.whl ../_docker/
cp hook.py ../_docker/

cd ../_docker/
docker build -t rushiai/auto-reloader .

rm -f *.whl hook.py
