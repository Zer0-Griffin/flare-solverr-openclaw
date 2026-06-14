# flare-solverr-openclaw

A plug-and-play Cloudflare solver for OpenClaw instances. Forked from FlareSolverr with an automated installer that detects your environment and configures everything in a single command.

## Features

- One-command installation on Windows, Linux, and macOS
- Automatic detection of available browsers (Chrome, Chromium, Brave)
- Configurable port, timeout, and log level via environment variables
- Docker support for containerized deployments
- Works with OpenClaw's web_fetch tool or Playwright browser automation
- Precompiled Windows x64 binary included — no Python installation required

## Original Project

This project is a fork of [FlareSolverr](https://github.com/FlareSolverr/FlareSolverr) by Diego Heras (ngosang). The core solver logic, undetected-chromedriver integration, and Cloudflare challenge handling are unchanged from the original.

Original repository: https://github.com/FlareSolverr/FlareSolverr
License: MIT License (see LICENSE file in this repo)

## Installation

### Single-command install (Windows)

```powershell
curl -sSL https://raw.githubusercontent.com/Zer0-Griffin/flaresolverr-openclaw/main/install.ps1 | powershell -ExecutionPolicy Bypass -
```

The installer will:
1. Detect your platform and architecture
2. Download the appropriate precompiled binary (Windows x64) or install from source
3. Place it in `%USERPROFILE%\.openclaw\flare-solverr\`
4. Write a config file at `%USERPROFILE%\.openclaw\flare-solverr\config.ini`
5. Optionally start the service

### Single-command install (Linux)

```bash
curl -sSL https://raw.githubusercontent.com/Zer0-Griffin/flaresolverr-openclaw/main/install.sh | bash
```

### Docker

```bash
docker run -d \
  --name=flaresolverr-openclaw \
  -p 8191:8191 \
  -e LOG_LEVEL=info \
  ghcr.io/Zer0-Griffin/flaresolverr-openclaw:latest
```

## Configuration

Edit `config.ini` in your installation directory:

```ini
[flaresolverr]
port = 8191
timeout_seconds = 60
language = en-US
user_agent = Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36
browser = chrome
url_base = http://localhost:8191
```

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `FLARESOLVERR_PORT` | `8191` | Port to listen on |
| `FLARESOLVERR_TIMEOUT_SECONDS` | `60` | Max time in seconds to solve a challenge |
| `LOG_LEVEL` | `info` | Logging level (debug, info, warn, error) |
| `PROXY_URL` | - | Proxy URL for requests |
| `BROWSER_PATH` | auto-detect | Path to your browser binary |

## OpenClaw Integration

After installation, configure OpenClaw to use FlareSolverr:

### Option 1: Via TOOLS.md (recommended)

Add this to your workspace TOOLS.md:

```markdown
### FlareSolverr
- URL: http://localhost:8191/
- Used for Cloudflare bypass via web_fetch proxy
```

Then in MEMORY.md, add the cookie-pass-through workflow:

> When interactive browser visits fail on CF-protected sites, first hit FlareSolverr at `http://localhost:8191`, extract cookies from response, then load into Playwright browser context.

### Option 2: Via web_fetch proxy

OpenClaw's `web_fetch` tool can use Firecrawl as a fallback for bot circumvention. For direct FlareSolverr integration, the agent calls FlareSolverr via exec/curl when CF is detected.

## Usage Examples

### Fetching a Cloudflare-protected page (via curl)

```powershell
$body = @{
  cmd = "request.get"
  url = "https://example.com/"
  maxTimeout = 60000
} | ConvertTo-Json

irm -UseBasicParsing 'http://localhost:8191/v1' `
  -Headers @{"Content-Type"="application/json"} `
  -Method Post -Body $body
```

### Fetching a Cloudflare-protected page (via Python)

```python
import requests

url = "http://localhost:8191/v1"
headers = {"Content-Type": "application/json"}
data = {
    "cmd": "request.get",
    "url": "https://example.com/",
    "maxTimeout": 60000
}
response = requests.post(url, headers=headers, json=data)
print(response.text)
```

## Self-Hosting on a Remote Machine (e.g., Proxmox VM)

If you host FlareSolverr on a separate machine (like your Boris hypervisor's VM):

1. Install on the remote machine using any method above
2. Ensure port 8191 is open in the firewall:
   - Windows: `New-NetFirewallRule -DisplayName "FlareSolverr" -Direction Inbound -LocalPort 8191 -Protocol TCP -Action Allow`
   - Linux: `ufw allow 8191/tcp`
3. Update your OpenClaw TOOLS.md with the remote VM's IP (e.g., `http://192.168.0.98:8191/`)

## Architecture

```
+-------------------+       HTTP POST        +--------------------+
|  OpenClaw Agent   | ------------------->  | FlareSolverr Proxy |
| (web_fetch / exec)|                       | (port 8191)        |
+-------------------+                       +--------------------+
                                                   |
                                              Selenium/Chrome
                                                  |
                                          Cloudflare Challenge
                                               Solved
```

## License

MIT License. See [LICENSE](LICENSE) for details.

FlareSolverr is Copyright (c) 2025 Diego Heras (ngosang).
This fork adds the OpenClaw installer wrapper and documentation on top of the original codebase.
