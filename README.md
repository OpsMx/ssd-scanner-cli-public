# ssd-scanner-cli-public
SSD CLI Tool for CI Scans

This is a commnd line tool to scan your source code/artifact with SSD supported security scanners (like grype, semgrep, etc) and generate a report. The generated report will be in JSON format and can be uploaded to SSD platform for further analysis. 

## Installation

```bash
curl -L -o install_ssd_scanner_cli.sh https://raw.githubusercontent.com/OpsMx/ssd-scanner-cli-public/refs/heads/main/install_ssd_scanner_cli.sh && chmod +x install_ssd_scanner_cli.sh && ./install_ssd_scanner_cli.sh

```
