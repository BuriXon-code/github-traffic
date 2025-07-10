# github-traffic

Get and display GitHub repository traffic stats (clones + visits) in terminal, JSON, or CSV format.  
Minimal, fast, and fully controlled via CLI.

---

## About

**github-traffic** is a pure Bash tool for retrieving GitHub repository traffic (clones and views).  
It connects to the GitHub REST API, fetches stats for all your public repos, and presents them in a clean, colored terminal layout — or exports them in JSON/CSV.

No external frameworks, no runtime dependencies.  
Built for power users, script automation, and privacy-conscious CLI workflows.

---

## Features

- Displays **clone count** and **visit count** for each repository
- Sort by most cloned or most visited
- Export to **JSON** or **CSV** (`--format`)
- Optional **pretty JSON** (`--pretty-json`)
- Colorful **terminal output** with trend arrows (↑ ↓)
- **Cache file** for comparing values between runs
- Limit number of results (`--lines`)
- Fully **non-interactive**
- Works with **personal GitHub token**
- Can be used in cron jobs, CI, or manually

>[!NOTE]
> Fetching data may take longer if you have many public repositories. Each repository requires a separate curl request.

---

## Installation

1. Clone the repository:

```
git clone https://github.com/BuriXon-code/github-traffic
```

2. Make the script executable:

```
chmod +x github-traffic/traffic.sh
```

3. (Optional) Move it into your PATH:

```
mv github-traffic/traffic.sh /usr/local/bin/traffic
```

---

## Usage

To run the script, you **must provide a GitHub personal access token (PAT)** and your GitHub username.

You can create a token at:  
[https://github.com/settings/tokens](https://github.com/settings/tokens)

Required scope:  
**`repo`** → _This allows reading repository metadata and traffic._

Recommended token format:  
Starts with `ghp_` or `github_pat_...` depending on GitHub version.

>[!NOTE]
> You can provide the username and API token as parameters, export them externally, or set default values inside the script using $GITHUB_USER and $GITHUB_TOKEN.

Example usage:

```
./traffic.sh -u your_username -t your_token
```

Sorting by clones or visits:

```
./traffic.sh -u your_username -t your_token -c
```

```
./traffic.sh -u your_username -t your_token -v
```

Limiting number of results:

```
./traffic.sh -u your_username -t your_token -c -l 10
```

Export to JSON / CSV:

```
./traffic.sh -u your_username -t your_token -f json -o output.json  
```

```
./traffic.sh -u your_username -t your_token -f csv -o output.csv
```

Pretty-printed JSON:

```
./traffic.sh -u your_username -t your_token -f json -j
```

![screenshot](/img.jpg)

---

### Flags & Options

| Flag            | Description                           |
|-----------------|---------------------------------------|
| `-u`, `--username`  | GitHub username                      |
| `-t`, `--token`     | GitHub personal access token         |
| `-c`, `--sort=clones` | Sort output by clone count        |
| `-v`, `--sort=visits` | Sort output by visit count        |
| `-l`, `--lines`     | Limit number of rows in output       |
| `-p`, `--per-page`  | Max repos per API page (default: 100) |
| `-f`, `--format`    | Output format: `json`, `csv` |
| `-o`, `--output`    | Output file (used with JSON/CSV)     |
| `-j`, `--pretty-json` | Pretty print JSON (requires `-f json`) |
| `-h`                | Show help message                    |

---

## Compatibility

- Runs on:
  - Termux (Android)
  - Debian / Ubuntu / Alpine
  - Any POSIX-compliant Linux shell

- Requires:
  - `bash`
  - `curl`
  - `jq`
  - GitHub token with `repo` access

---

## Notes

- The GitHub API provides traffic data for the **last 14 days only**
- The script creates a local **cache file** in `~/.cache/BuriXon-code/github/<your_username>`
- Trends (↑ ↓) are shown by comparing with the last saved stats
- When exporting as JSON or CSV, sorting and limit flags are ignored
- You can run this script via cron to periodically collect or export data

---

## Support
### Contact me:
For any issues, suggestions, or questions, reach out via:

- **Email:** support@burixon.dev  
- **Contact form:** [Click here](https://burixon.dev/contact/)

### Support me:
If you find this script useful, consider supporting my work by making a donation:

[**DONATE HERE**](https://burixon.dev/donate/)

Your contributions help in developing new projects and improving existing tools!

---
