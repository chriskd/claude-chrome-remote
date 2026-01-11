# Claude Chrome Remote

Use Claude Code's browser automation from a remote machine by tunneling the Chrome extension's socket over SSH.

## The Problem

Claude Code's browser automation requires the Claude Chrome extension running locally. But if you're running Claude Code on a remote dev server (via SSH), it can't connect to your local browser.

## The Solution

This script tunnels the extension's Unix socket from your local machine to the remote server, letting remote Claude Code control your local Chrome as if it were running locally.

## Quick Start

```bash
# On your local machine (where Chrome is running)
./tunnel-socket.sh user@remote-host
```

Keep this terminal open. On your remote machine, Claude Code can now use browser automation:

```bash
claude
# Then use /chrome or ask Claude to interact with web pages
```

## Requirements

**Local machine (where Chrome runs):**
- macOS or Linux
- Chrome with [Claude extension](https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn) installed
- Extension sidebar opened at least once (to start the native messaging host)
- SSH client with Unix socket forwarding (OpenSSH 6.7+)

**Remote machine (where Claude Code runs):**
- Linux or macOS
- Claude Code installed
- SSH server running

## How It Works

### Architecture

```
┌─────────────────────────────────────┐     ┌─────────────────────────────────────┐
│         LOCAL MACHINE               │     │         REMOTE MACHINE              │
│         (Your laptop)               │     │         (Dev server)                │
│                                     │     │                                     │
│  ┌─────────────────────────────┐    │     │    ┌─────────────────────────────┐  │
│  │     Chrome Browser          │    │     │    │       Claude Code           │  │
│  │  ┌───────────────────────┐  │    │     │    │                             │  │
│  │  │  Claude Extension     │  │    │     │    │  "Open example.com and      │  │
│  │  │  (sidebar panel)      │  │    │     │    │   click the login button"   │  │
│  │  └───────────┬───────────┘  │    │     │    │                             │  │
│  └──────────────┼──────────────┘    │     │    └──────────────┬──────────────┘  │
│                 │ Native Messaging  │     │                   │ MCP Protocol    │
│                 ▼                   │     │                   ▼                 │
│  ┌─────────────────────────────┐    │     │    ┌─────────────────────────────┐  │
│  │   Native Messaging Host     │    │     │    │      Unix Socket            │  │
│  │   (bridge process)          │    │     │    │      (tunneled)             │  │
│  └──────────────┬──────────────┘    │     │    └──────────────┬──────────────┘  │
│                 │                   │     │                   │                 │
│                 ▼                   │     │                   │                 │
│  ┌─────────────────────────────┐    │     │    ┌─────────────────────────────┐  │
│  │      Unix Socket            │◄───┼─────┼───►│  $TMPDIR/claude-mcp-        │  │
│  │  $TMPDIR/claude-mcp-        │    │     │    │  browser-bridge-$USER       │  │
│  │  browser-bridge-$USER       │    │ SSH │    │                             │  │
│  └─────────────────────────────┘    │ -R  │    └─────────────────────────────┘  │
│                                     │     │                                     │
└─────────────────────────────────────┘     └─────────────────────────────────────┘
```

### Step by Step

1. **Chrome extension starts a native messaging host** - When you open the Claude extension sidebar, it launches a native process that creates a Unix socket at `$TMPDIR/claude-mcp-browser-bridge-$USER`

2. **This script creates an SSH reverse tunnel** - Using `ssh -R`, the local socket is forwarded to the same path on the remote machine

3. **Remote Claude Code connects normally** - Claude Code looks for the socket at the standard path. It doesn't know (or care) that it's actually tunneled to your local machine

4. **Commands flow through the tunnel** - When Claude Code sends browser commands, they travel through SSH to your local native host, which forwards them to Chrome

### Extension Status Workaround

Claude Code's `/chrome` command checks if the extension is installed by looking for its directory in Chrome's profile. Since Chrome isn't installed on the remote machine, this check would fail.

The script works around this by creating an empty directory at the expected path:
```
~/.config/google-chrome/Default/Extensions/fcoeoabgfenejglbffodgkkbkcdhcgfn
```

This directory is:
- Created only if it doesn't already exist (won't clobber existing files)
- Automatically removed when the tunnel disconnects
- Optional - if creation fails, you'll see a warning but the tunnel still works

## What Gets Tunneled

| Direction | Data |
|-----------|------|
| Remote → Local | MCP commands (navigate, click, screenshot, etc.) |
| Local → Remote | Page content, screenshots, command results |

All traffic is encrypted by SSH. The socket only accepts local connections on both ends.

## Troubleshooting

### "Socket not found" / "Waiting for socket..."

The native messaging host hasn't started yet.

**Fix:** Open Chrome and click on the Claude extension icon to open its sidebar. This triggers the native host to start and create the socket.

### "remote port forwarding failed"

A stale socket file exists on the remote machine from a previous session.

**Fix:** The script automatically cleans this up, but if it persists:
```bash
ssh remote-host 'rm -f $TMPDIR/claude-mcp-browser-bridge-*'
```

### "/chrome shows extension not installed" on remote

The extension directory workaround may have failed.

**Fix:** Manually create the directory:
```bash
mkdir -p ~/.config/google-chrome/Default/Extensions/fcoeoabgfenejglbffodgkkbkcdhcgfn
```

### "SSH doesn't support socket forwarding"

You need OpenSSH 6.7 or later, which added Unix domain socket forwarding.

**Fix:** Upgrade your SSH client. On macOS, the built-in SSH is modern enough. On older Linux, you may need to update.

### Browser commands timeout or fail

The tunnel may have disconnected, or Chrome/the extension was closed.

**Fix:**
1. Check that the tunnel script is still running on your local machine
2. Verify Chrome is open with the extension sidebar visible
3. Restart the tunnel if needed

## Limitations

- **One browser per tunnel** - Each tunnel connects one remote Claude Code instance to one local Chrome
- **Latency** - There's some added latency from the SSH tunnel, but it's generally not noticeable
- **Must keep terminal open** - The tunnel runs in the foreground; closing it disconnects the bridge

## Security Considerations

- The socket only accepts local connections (no network exposure)
- All traffic is encrypted via SSH
- The remote machine can control your local browser while connected - only tunnel to machines you trust
- The script doesn't store credentials or modify Chrome settings

## License

MIT
