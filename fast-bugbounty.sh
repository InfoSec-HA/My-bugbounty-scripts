#!/bin/bash

# ألوان
green='\033[0;32m'
nc='\033[0m'

# 1. اسم النطاق
read -p "Enter target domain (e.g. example.com): " domain
folder=$(echo $domain | tr -d '*')
mkdir -p recon/$folder
cd recon/$folder

# 2. جمع النطاقات الفرعية
echo -e "${green}[+] Collecting subdomains...${nc}"
subfinder -d $domain -all -silent -o subfinder.txt
assetfinder --subs-only $domain >> assetfinder.txt
amass enum -passive -d $domain -o amass.txt

# 3. دمج وتصفية
echo -e "${green}[+] Merging and filtering unique subdomains...${nc}"
cat subfinder.txt assetfinder.txt amass.txt | sort -u > all_subdomains.txt

# 4. فحص الحية
echo -e "${green}[+] Probing for live subdomains...${nc}"
cat all_subdomains.txt | httpx -silent -no-color > alive.txt

# 5. فحص الثغرات باستخدام nuclei
echo -e "${green}[+] Scanning for vulnerabilities using nuclei...${nc}"
mkdir -p nuclei-results
nuclei -l alive.txt -t "cves/,vulnerabilities/,misconfiguration/,exposures/,files/" -severity low,medium,high,critical -o nuclei-results/vulns.txt -silent

# 6. فحص XSS و Open Redirect فقط
echo -e "${green}[+] Scanning specifically for XSS and Open Redirect...${nc}"
nuclei -l alive.txt -t "xss/" -o nuclei-results/xss.txt -silent
nuclei -l alive.txt -t "redirect/" -o nuclei-results/redirects.txt -silent

# 7. عرض النتائج النهائية
echo -e "${green}[✔] Finished. Results in: recon/$folder/nuclei-results/${nc}"
ls -lh nuclei-results/
