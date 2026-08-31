#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$DIR/scripts/make_dmg.sh" "$@"
