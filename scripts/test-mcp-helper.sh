#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PACKAGE="$ROOT/MCPHelper"

swift build --package-path "$PACKAGE" --product GodexUMCPServer
swift build --package-path "$PACKAGE" --product GodexUMCPProbe
swift run --package-path "$PACKAGE" GodexUMCPContractTests

BIN_DIR="$(swift build --package-path "$PACKAGE" --show-bin-path)"
"$BIN_DIR/GodexUMCPProbe" "$BIN_DIR/GodexUMCPServer"

echo "MCP helper tests passed"
