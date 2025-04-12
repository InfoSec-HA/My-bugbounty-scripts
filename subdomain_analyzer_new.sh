#!/bin/bash

# Check for required tools
REQUIRED_TOOLS=("curl" "parallel" "grep" "awk")
for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" &> /dev/null; then
    echo "Error: $tool is not installed!"
    exit 1
  fi
done

# File configuration
SUBDOMAINS_FILE="subfinder_subdomins.txt"
OUTPUT_FILE="subdomains_analysis.csv"
TMP_DIR=$(mktemp -d)

# Initialize output file
echo "Subdomain,Status Code,Protocol,Content Type,Is API,Is Static" > "$OUTPUT_FILE"

# Analysis function
analyze_subdomain() {
  local subdomain="$1"
  local tmp_file=$(mktemp -p "$TMP_DIR")
  
  # Try HTTPS first
  local https_response=$(curl -sI -L --connect-timeout 5 --max-time 8 "https://$subdomain" 2>/dev/null)
  local status_code=$(echo "$https_response" | grep -i "HTTP/" | awk '{print $2}' | tail -n 1)
  local protocol="HTTPS"

  # Fallback to HTTP if HTTPS fails
  if [[ -z "$status_code" || "$status_code" == "000" ]]; then
    local http_response=$(curl -sI -L --connect-timeout 5 --max-time 8 "http://$subdomain" 2>/dev/null)
    status_code=$(echo "$http_response" | grep -i "HTTP/" | awk '{print $2}' | tail -n 1)
    protocol="HTTP"
  fi

  # Content analysis
  local content_type=$(echo -e "$https_response\n$http_response" | grep -i "Content-Type:" | awk -F': ' '{print $2}' | head -n 1)
  local is_api="No"
  local is_static="No"

  [[ "$content_type" == *"json"* || "$subdomain" =~ (api|v[0-9]+) ]] && is_api="Yes"
  [[ "$content_type" == *"text/html"* ]] && is_static="Yes"

  # Save to temporary file
  echo "$subdomain,$status_code,$protocol,\"$content_type\",$is_api,$is_static" > "$tmp_file"
}

# Export functions and variables
export -f analyze_subdomain
export TMP_DIR

# Parallel processing (20 jobs)
cat "$SUBDOMAINS_FILE" | parallel -j 20 --bar --eta analyze_subdomain

# Combine results
find "$TMP_DIR" -type f -exec cat {} + >> "$OUTPUT_FILE"

# Cleanup
rm -rf "$TMP_DIR"
echo -e "\nDone! Results saved to: $OUTPUT_FILE"