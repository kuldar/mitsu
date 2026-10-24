#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
sh app/scripts/test-core.sh
zsh tools/test-native.sh
sh tools/test-body-data.sh
sh tools/test-controls.sh
python3 -m unittest discover -s tests -p 'test_*.py'
python3 tools/audit_public.py
