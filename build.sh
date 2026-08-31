#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$DIR/scripts/build.sh" "$@"
