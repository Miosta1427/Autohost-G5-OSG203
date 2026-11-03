#!/bin/bash

# Kiem tra quyen root (sudo)
if [ "$EUID" -ne 0 ]; then
  echo "Vui long chay script voi quyen sudo: sudo $0"
  exit 1
fi

echo "=== DANG CAU HINH TUONG LUA UFW ==="

# 1. Reset cau hinh ve mac dinh de tranh xung dot
ufw --force reset

# 2. Quy tac mac dinh: Chan tat ca ket noi vao, cho phep tat ca ket noi ra
ufw default deny incoming
ufw default allow outgoing

# 3. Chi mo 3 cong can thiet: 22 (SSH), 80 (HTTP), 443 (HTTPS)
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'Apache HTTP'
ufw allow 443/tcp comment 'Apache HTTPS'

# 4. Kich hoat tuong lua
ufw --force enable

echo "=================================="
echo "Cau hinh UFW thanh cong!"
echo "=== TRANG THAI TUONG LUA HIEN TAI ==="
ufw status verbose
