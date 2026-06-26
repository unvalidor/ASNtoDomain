#!/bin/bash


DOMAIN=$1
OUTDIR="recon-$DOMAIN"

mkdir -p $OUTDIR
cd $OUTDIR || exit

echo "[+] Target: $DOMAIN"


echo "[+] Extracting ASN & CIDR ranges..."
echo $DOMAIN | asnmap -silent -o asn.txt


cat asn.txt | grep -Eo "([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+" > cidr.txt

echo "[+] Found CIDRs:"
wc -l cidr.txt


echo "[+] Expanding CIDR to IPs..."
cat cidr.txt | mapcidr -silent -o ips.txt

echo "[+] Total IPs:"
wc -l ips.txt

echo "[+] Probing HTTP/HTTPS services..."
cat ips.txt | httpx -sc 200 -silent -threads 200 -o alive-http.txt

echo "[+] Alive HTTP services:"
wc -l alive-http.txt

echo "[+] Done ✅"
echo "Results saved in: $OUTDIR"
