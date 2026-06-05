#!/bin/bash
set -e

cd /home/user1/lab/aws

echo "======================================"
echo "Pre-Git Safety Check"
echo "======================================"

echo ""
echo "[1] Check required files"

REQUIRED_FILES=(
  "00_syntax_check.sh"
  "00_run_all.sh"
  "01_create_base_network.yml"
  "02_create_security_groups.yml"
  "03_create_compute.yml"
  "04_create_alb.yml"
  "05_validate.yml"
  "06_generate_inventory.yml"
  "07_check_web_servers.yml"
  "08_generate_report.yml"
  "99_delete_all.sh"
  "README.md"
  ".gitignore"
)

for FILE in "${REQUIRED_FILES[@]}"; do
  if [ -f "$FILE" ]; then
    echo "OK: $FILE"
  else
    echo "MISSING: $FILE"
    exit 1
  fi
done

echo ""
echo "[2] Check dangerous files"

DANGEROUS_FILES=(
  "ansible-jjh-key"
  "ansible-jjh-key.pub"
  "inventory.ini"
)

for FILE in "${DANGEROUS_FILES[@]}"; do
  if [ -f "$FILE" ]; then
    echo "WARNING: $FILE exists. It should not be committed."
  else
    echo "OK: $FILE not found"
  fi
done

echo ""
echo "[3] Check generated output files"

for FILE in output/base_network.yml output/security_groups.yml output/compute.yml output/alb.yml output/validation.yml; do
  if [ -f "$FILE" ]; then
    echo "WARNING: $FILE exists. It should be ignored by Git."
  else
    echo "OK: $FILE not found"
  fi
done

echo ""
echo "[4] Check sanitized examples"

EXAMPLE_FILES=(
  "output/example/base_network.example.yml"
  "output/example/security_groups.example.yml"
  "output/example/compute.example.yml"
  "output/example/alb.example.yml"
  "output/example/validation.example.yml"
)

for FILE in "${EXAMPLE_FILES[@]}"; do
  if [ -f "$FILE" ]; then
    echo "OK: $FILE"
  else
    echo "MISSING: $FILE"
    exit 1
  fi
done

echo ""
echo "[5] Check git ignored files"

if command -v git >/dev/null 2>&1; then
  git check-ignore ansible-jjh-key >/dev/null 2>&1 && echo "OK: ansible-jjh-key ignored" || echo "WARNING: ansible-jjh-key not ignored"
  git check-ignore inventory.ini >/dev/null 2>&1 && echo "OK: inventory.ini ignored" || echo "WARNING: inventory.ini not ignored"
  git check-ignore output/base_network.yml >/dev/null 2>&1 && echo "OK: output/base_network.yml ignored" || echo "WARNING: output/base_network.yml not ignored"
else
  echo "SKIP: git command not found"
fi

echo ""
echo "======================================"
echo "Pre-Git Safety Check Completed"
echo "======================================"
