# ssd-scanner-cli-public
SSD CLI Tool for CI Scans

This is a commnd line tool to scan your source code/artifact with SSD supported security scanners (like grype, semgrep, etc) and generate a report. The generated report will be in JSON format and can be uploaded to SSD platform for further analysis. 

## Installation

```bash
curl -L -o ssd-scanner-cli https://github.com/OpsMx/ssd-scanner-cli-public/releases/latest/download/ssd-scanner-cli
sudo chmod +x ./ssd-scanner-cli
sudo cp ssd-scanner-cli /usr/local/bin
```
