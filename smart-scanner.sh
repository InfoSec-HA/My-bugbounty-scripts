#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

usage() {
    echo -e "Usage: $0 -d domain.com [--xss] [--redirect] [--report]"
    exit 1
}

# Flags
XSS=false
REDIRECT=false
REPORT=false

# Parse args
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -d|--domain) DOMAIN="$2"; shift ;;
        --xss) XSS=true ;;
        --redirect) REDIRECT=true ;;
        --report) REPORT=true ;;
        *) usage ;;
    esac
    shift
done

if [ -z "$DOMAIN" ]; then
    usage
fi

OUTPUT_DIR="output/$DOMAIN"
mkdir -p "$OUTPUT_DIR"

echo -e "${GREEN}[+] Gathering subdomains...${NC}"
subfinder -d "$DOMAIN" -silent >> "$OUTPUT_DIR/subs.txt"
assetfinder --subs-only "$DOMAIN" >> "$OUTPUT_DIR/subs.txt"
amass enum -passive -d "$DOMAIN" >> "$OUTPUT_DIR/subs.txt"
sort -u "$OUTPUT_DIR/subs.txt" > "$OUTPUT_DIR/final_subs.txt"

echo -e "${GREEN}[+] Probing live hosts...${NC}"
cat "$OUTPUT_DIR/final_subs.txt" | httprobe > "$OUTPUT_DIR/alive.txt"

if [ "$XSS" = true ]; then
    echo -e "${GREEN}[+] Extracting URLs for XSS...${NC}"
    cat "$OUTPUT_DIR/alive.txt" | gau --o "$OUTPUT_DIR/urls.txt" > /dev/null
    cat "$OUTPUT_DIR/alive.txt" | waybackurls >> "$OUTPUT_DIR/urls.txt"
    sort -u "$OUTPUT_DIR/urls.txt" > "$OUTPUT_DIR/final_urls.txt"

    echo -e "${GREEN}[+] Scanning for XSS with dalfox...${NC}"
    dalfox file "$OUTPUT_DIR/final_urls.txt" --skip-bav -o "$OUTPUT_DIR/xss.txt"
fi

if [ "$REDIRECT" = true ]; then
    echo -e "${GREEN}[+] Scanning for Open Redirects using gf...${NC}"
    cat "$OUTPUT_DIR/final_urls.txt" | gf redirect > "$OUTPUT_DIR/redirects.txt"
    nuclei -l "$OUTPUT_DIR/redirects.txt" -t vulnerabilities/ -o "$OUTPUT_DIR/nuclei_redirects.txt"
fi

if [ "$REPORT" = true ]; then
    echo -e "${GREEN}[+] Generating report...${NC}"
    REPORT_FILE="$OUTPUT_DIR/report_$(date +%Y%m%d_%H%M).txt"
    {
        echo "=== Report for $DOMAIN ==="
        echo "[+] Subdomains: $(wc -l < "$OUTPUT_DIR/final_subs.txt")"
        echo "[+] Live hosts: $(wc -l < "$OUTPUT_DIR/alive.txt")"
        echo ""
        [ -f "$OUTPUT_DIR/xss.txt" ] && echo "[*] XSS Findings:" && cat "$OUTPUT_DIR/xss.txt"
        [ -f "$OUTPUT_DIR/nuclei_redirects.txt" ] && echo "[*] Open Redirects:" && cat "$OUTPUT_DIR/nuclei_redirects.txt"
    } > "$REPORT_FILE"

    echo -e "${GREEN}[✓] Report saved to: $REPORT_FILE${NC}"
fi

echo -e "${GREEN}[✓] Done.${NC}"
