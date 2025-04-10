#!/bin/bash

# اسم الهدف
read -p "Enter target domain (e.g. example.com): " domain
folder=$(echo $domain | tr -d '*')
mkdir -p recon/$folder
cd recon/$folder

echo "[+] Collecting subdomains with subfinder..."
subfinder -d $domain -all -silent -o subfinder.txt

echo "[+] Collecting subdomains with assetfinder..."
assetfinder --subs-only $domain | tee assetfinder.txt

echo "[+] Collecting subdomains with amass (passive)..."
amass enum -passive -d $domain -o amass.txt

echo "[+] Combining and sorting unique subdomains..."
cat subfinder.txt assetfinder.txt amass.txt | sort -u > all_subdomains.txt

echo "[+] Probing for live hosts using httpx..."
cat all_subdomains.txt | httpx -no-color -status-code -title -tech-detect -o alive.txt

echo "[+] Done! Results are in: recon/$folder/"
