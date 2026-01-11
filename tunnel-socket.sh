#!/bin/bash
#
# Tunnel the Chrome extension's socket to a remote machine.
#
# This script:
# 1. Finds the local socket created by the native host
# 2. SSH tunnels it to the remote machine
# 3. Claude Code on the remote can then connect to the browser extension!
#
# NO manifest changes needed. Completely non-invasive.
#
# Usage: ./tunnel-socket.sh [user@]remote-host
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo "Usage: $0 [user@]remote-host"
    echo ""
    echo "Example: $0 dev-machine"
    echo "         $0 user@dev-machine.example.com"
    exit 1
fi

REMOTE_HOST="$1"
LOCAL_USER=$(whoami)
# Normalize TMPDIR (remove trailing slash if present)
LOCAL_TMPDIR="${TMPDIR%/}"
LOCAL_SOCKET="$LOCAL_TMPDIR/claude-mcp-browser-bridge-$LOCAL_USER"

echo "=========================================="
echo "Claude Chrome Extension Socket Tunnel"
echo "=========================================="
echo ""

# Check if local socket exists, wait for it if not
if [ ! -S "$LOCAL_SOCKET" ]; then
    echo -e "${YELLOW}Waiting for socket...${NC}"
    echo "Open the Claude extension sidebar in Chrome to start the native host."
    echo ""
    for i in {1..30}; do
        if [ -S "$LOCAL_SOCKET" ]; then
            echo -e "${GREEN}Socket found!${NC}"
            break
        fi
        sleep 1
        echo -n "."
    done
    echo ""

    if [ ! -S "$LOCAL_SOCKET" ]; then
        echo -e "${RED}Error: Socket not found after 30 seconds${NC}"
        echo ""
        echo "Make sure:"
        echo "  1. Chrome is running with the Claude extension installed"
        echo "  2. Open the extension sidebar to trigger connection"
        echo ""
        echo "Expected socket at: $LOCAL_SOCKET"
        exit 1
    fi
fi

echo -e "${GREEN}Found local socket:${NC} $LOCAL_SOCKET"

# Get remote TMPDIR (normalized)
echo -n "Getting remote TMPDIR... "
REMOTE_TMPDIR=$(ssh -o BatchMode=yes "$REMOTE_HOST" 'echo ${TMPDIR%/}' 2>/dev/null)
if [ -z "$REMOTE_TMPDIR" ]; then
    # Fallback to /tmp if TMPDIR is not set
    REMOTE_TMPDIR="/tmp"
fi
echo "$REMOTE_TMPDIR"

# Get remote username
REMOTE_USER=$(ssh -o BatchMode=yes "$REMOTE_HOST" 'whoami' 2>/dev/null)
echo "Remote user: $REMOTE_USER"

REMOTE_SOCKET="$REMOTE_TMPDIR/claude-mcp-browser-bridge-$REMOTE_USER"
echo -e "${CYAN}Will create remote socket:${NC} $REMOTE_SOCKET"
echo ""

# Clean up any existing remote socket
echo "Cleaning up any stale remote socket..."
ssh -o BatchMode=yes "$REMOTE_HOST" "rm -f '$REMOTE_SOCKET'" 2>/dev/null || true

# Start the tunnel
echo ""
echo -e "${GREEN}Starting socket tunnel...${NC}"
echo ""
echo "The tunnel will stay open until you press Ctrl+C."
echo "On your remote machine, you can now run 'claude' and it will"
echo "connect to this Chrome extension!"
echo ""
echo "=========================================="
echo ""

# Use SSH's StreamLocalBindUnlink to auto-remove stale sockets
# -N: don't execute remote command
# -T: disable pseudo-terminal
ssh -o StreamLocalBindUnlink=yes \
    -o ExitOnForwardFailure=yes \
    -R "$REMOTE_SOCKET:$LOCAL_SOCKET" \
    -N -T \
    "$REMOTE_HOST"
