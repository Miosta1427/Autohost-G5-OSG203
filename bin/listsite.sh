#!/bin/bash

# ============================================
# listsite.sh - Liet ke cac web dang chay
# In ra: Ten site, Dung luong, Han SSL
# ============================================

# Kiem tra quyen root
if [ "$EUID" -ne 0 ]; then
  echo "Vui long chay voi quyen sudo: sudo $0"
  exit 1
fi

echo "============================================================"
echo "         DANH SACH CAC WEBSITE DANG CHAY"
echo "============================================================"

# In tieu de bang
printf "%-25s %-15s %-30s\n" "TEN SITE" "DUNG LUONG" "HAN CHUNG CHI SSL"
printf "%-25s %-15s %-30s\n" "--------" "---------" "-----------------"

# Dem so site
count=0

# Duyet qua tat ca file cau hinh trong sites-enabled (cac site dang bat)
for conf in /etc/apache2/sites-enabled/*.conf; do

  # Kiem tra xem co file conf nao khong
  [ -f "$conf" ] || continue

  # Lay ten site tu ten file (bo duoi .conf)
  site=$(basename "$conf" .conf)

  # Bo qua cac site mac dinh cua Apache
  if [ "$site" = "000-default" ] || [ "$site" = "default-ssl" ]; then
    continue
  fi

  # Lay duong dan thu muc web tu dong DocumentRoot trong file conf
  docroot=$(grep -i "DocumentRoot" "$conf" | head -1 | awk '{print $2}')

  # Tinh dung luong thu muc web
  if [ -n "$docroot" ] && [ -d "$docroot" ]; then
    size=$(du -sh "$docroot" 2>/dev/null | awk '{print $1}')
  else
    size="N/A"
  fi

  # Tim ngay het han chung chi SSL
  certfile=$(grep -i "SSLCertificateFile" "$conf" 2>/dev/null | head -1 | awk '{print $2}')

  if [ -n "$certfile" ] && [ -f "$certfile" ]; then
    # Doc file chung chi va lay ngay het han
    expiry=$(openssl x509 -enddate -noout -in "$certfile" 2>/dev/null | cut -d= -f2)
  else
    expiry="Khong co SSL"
  fi

  # In ra 1 dong trong bang
  printf "%-25s %-15s %-30s\n" "$site" "$size" "$expiry"

  count=$((count + 1))

done

# Kiem tra them cac site Userdir (web ca nhan cua user)
echo ""
echo "============================================================"
echo "         DANH SACH WEB CA NHAN (USERDIR)"
echo "============================================================"
printf "%-25s %-15s\n" "USER" "DUNG LUONG"
printf "%-25s %-15s\n" "----" "---------"

user_count=0

for userdir in /home/*/public_html; do

  # Kiem tra xem co thu muc public_html nao khong
  [ -d "$userdir" ] || continue

  # Lay ten user tu duong dan
  username=$(echo "$userdir" | cut -d/ -f3)

  # Tinh dung luong
  size=$(du -sh "$userdir" 2>/dev/null | awk '{print $1}')

  printf "%-25s %-15s\n" "~$username" "$size"

  user_count=$((user_count + 1))

done

echo ""
echo "============================================================"
echo "
