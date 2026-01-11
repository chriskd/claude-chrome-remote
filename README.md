# Claude Chrome Remote

Tunnel the Claude Chrome extension to a remote machine, letting you use browser automation from Claude Code running on a remote dev server.

## Quick Start

```bash
# On your local machine (with Chrome)
./tunnel-socket.sh user@remote-host
```

That's it. Keep this running, then on your remote machine:

```bash
claude --chrome
```

## Requirements

**Local machine:**
- macOS or Linux
- Chrome with [Claude extension](https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn) installed
- SSH client with Unix socket forwarding (OpenSSH 6.7+)

**Remote machine:**
- Linux (tested on Debian/Ubuntu)
- Claude Code installed
- SSH server

## How It Works

```
[Local Machine]                              [Remote Machine]
Chrome Extension                              Claude Code
    ↓                                              ↓
Native Messaging Host                              │
    ↓                                              │
Unix Socket ◄──────── SSH -R tunnel ──────────────►│
$TMPDIR/claude-mcp-browser-bridge-$USER            │
                                                   ▼
                                         Browser automation!
```

The Claude extension's native messaging host creates a Unix socket for MCP communication. This script tunnels that socket to your remote machine via SSH, allowing remote Claude Code to control your local browser.

## Troubleshooting

**"Socket not found"**
- Make sure Chrome is running with the Claude extension
- Open the extension sidebar at least once to trigger the native host

**"remote port forwarding failed"**
- A stale socket may exist on the remote. The script tries to clean it up, but you can manually run: `ssh remote 'rm -f $TMPDIR/claude-mcp-browser-bridge-*'`

**SSH doesn't support socket forwarding**
- Upgrade to OpenSSH 6.7+ which added Unix socket forwarding

## License

MIT
