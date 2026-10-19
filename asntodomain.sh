#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[-]${NC} $1"; }

check_go() {
    if ! command -v go &>/dev/null; then
        error "Go is not installed. Installing..."
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y golang-go
        elif command -v yum &>/dev/null; then
            sudo yum install -y golang
        elif command -v brew &>/dev/null; then
            brew install go
        else
            error "Unsupported package manager. Please install Go manually."
            exit 1
        fi
    else
        info "Go is installed: $(go version)"
    fi
}

check_and_install_tool() {
    local tool_name=$1
    local install_path=$2

    if command -v "$tool_name" &>/dev/null; then
        info "$tool_name is installed ✓"
    else
        warn "$tool_name is not installed. Installing..."
        go install "$install_path" 2>/dev/null
        if [ $? -ne 0 ]; then
            error "Failed to install $tool_name"
            return 1
        fi
        export PATH=$PATH:$(go env GOPATH)/bin
        info "$tool_name installed successfully ✓"
    fi
}

check_jq() {
    if ! command -v jq &>/dev/null; then
        warn "jq is not installed (optional). Installing..."
        if command -v apt &>/dev/null; then
            sudo apt install -y jq
        elif command -v yum &>/dev/null; then
            sudo yum install -y jq
        elif command -v brew &>/dev/null; then
            brew install jq
        fi
    fi
}

info "Checking prerequisites..."

check_go
check_jq

export PATH=$PATH:$(go env GOPATH)/bin

if ! grep -q 'export PATH=$PATH:$(go env GOPATH)/bin' ~/.bashrc 2>/dev/null; then
    echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
fi

check_and_install_tool "asnmap"   "github.com/projectdiscovery/asnmap/cmd/asnmap@latest"
check_and_install_tool "mapcidr"  "github.com/projectdiscovery/mapcidr/cmd/mapcidr@latest"
check_and_install_tool "httpx"    "github.com/projectdiscovery/httpx/cmd/httpx@latest"

for t in asnmap mapcidr httpx; do
    if ! command -v $t &>/dev/null; then
        error "$t is still not in PATH. Please restart your terminal or set PATH manually."
        exit 1
    fi
done

info "All prerequisites are ready ✓"
echo

if [ -z "$1" ]; then
    error "Usage: $0 <domain>"
    echo "Example: $0 example.com"
    exit 1
fi

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
cat ips.txt | httpx -sc 200 -silent -threads 200 -td -o alive-http.txt

echo "[+] Alive HTTP services:"
wc -l alive-http.txt

echo "[+] Done ✅"
echo "Results saved in: $OUTDIR"
