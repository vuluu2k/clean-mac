#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./Scripts/build-app.sh
open "$PWD/dist/clean-mac.app"
