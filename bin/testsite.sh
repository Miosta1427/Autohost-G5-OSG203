#!/bin/bash

# ============================================
# testsite.sh - Kiem tra chuyen huong HTTP/HTTPS
# va kiem tra loi cau hinh Apache
# ============================================

# Kiem tra quyen root
if [ "$EUID" -ne 0 ]; then
  echo "Vui long chay voi quyen sudo: sudo $0 [domain_hoac_IP]"
  exit 1
fi

# Lay tham so truyen vao (neu khong co thi mac dinh la localhost)
SITE=${1:-localhost}

echo "============================================================"
echo "  KIEM TRA WEBSITE: $SITE"
echo "============================================================"
echo ""

# Bien dem so loi
errors=0

# -----------------------------------------------
# PHAN 1: KIEM TRA CAU HINH APACHE (configtest)
# -----------------------------------------------
echo "[1/3] KIEM TRA CU PHAP CAU HINH APACHE..."
echo "------------------------------------------------------------"

result=$(apache2ctl configtest 2>&1)

if echo "$result" | grep -q "Syntax OK"; then
  echo "  >> KET QUA: Syntax OK - Cau hinh Apache KHONG co loi!"
  echo ""
else
  echo "  >> KET QUA: CO LOI trong cau hinh Apache!"
  echo "  >> Chi tiet loi:"
  echo "$result"
  echo ""
  errors=$((errors + 1))
fi

# -----------------------------------------------
# PHAN 2: KIEM TRA CHUYEN HUONG HTTP -> HTTPS (301)
# -----------------------------------------------
echo "[2/3] KIEM TRA CHUYEN HUONG HTTP (80) -> HTTPS (443)..."
echo "------------------------------------------------------------"

# Gui yeu cau HTTP va lay ma trang thai
http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://$SITE" 2>/dev/null)

if [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
  echo "  >> Truy cap HTTP tra ve ma: $http_code (Chuyen huong)"

  # Lay dia chi chuyen huong den
  redirect_url=$(curl -s -o /dev/null -w "%{redirect_url}" "http://$SITE" 2>/dev/null)
  echo "  >> Chuyen huong den: $redirect_url"

  # Kiem tra xem dia chi chuyen huong co phai HTTPS khong
  if echo "$redirect_url" | grep -qi "^https://"; then
    echo "  >> KET QUA: DUNG - HTTP da chuyen huong sang HTTPS!"
  else
    echo "  >> KET QUA: SAI - Chuyen huong nhung KHONG PHAI sang HTTPS!"
    errors=$((errors + 1))
  fi

elif [ "$http_code" = "200" ]; then
  echo "  >> Truy cap HTTP tra ve ma: 200 (OK - Khong chuyen huong)"
  echo "  >> KET QUA: Trang web HTTP dang hoat dong nhung KHONG tu dong chuyen sang HTTPS."
  echo "  >> (Neu muon bat chuyen huong, can them RewriteRule vao cau hinh Apache)"

else
  echo "  >> Truy cap HTTP tra ve ma: $http_code"
  echo "  >> KET QUA: KHONG truy cap duoc trang web qua HTTP!"
  errors=$((errors + 1))
fi

echo ""

# -----------------------------------------------
# PHAN 3: KIEM TRA TRUY CAP HTTPS (200)
# -----------------------------------------------
echo "[3/3] KIEM TRA TRUY CAP HTTPS (443)..."
echo "------------------------------------------------------------"

# Gui yeu cau HTTPS (dung -k de bo qua loi chung chi tu ky)
https_code=$(curl -sk -o /dev/null -w "%{http_code}" "https://$SITE" 2>/dev/null)

if [ "$https_code" = "200" ]; then
  echo "  >> Truy cap HTTPS tra ve ma: 200 (OK)"
  echo "  >> KET QUA: Trang web HTTPS dang hoat dong BINH THUONG!"

elif [ "$https_code" = "000" ]; then
  echo "  >> Truy cap HTTPS tra ve ma: 000 (Khong ket noi duoc)"
  echo "  >> KET QUA: Cong 443 CHUA duoc bat hoac Apache CHUA cau hinh SSL!"
  errors=$((errors + 1))

else
  echo "  >> Truy cap HTTPS tra ve ma: $https_code"
  echo "  >> KET QUA: HTTPS co van de, can kiem tra lai cau hinh SSL!"
  errors=$((errors + 1))
fi

echo ""

# -----------------------------------------------
# TONG KET
# -----------------------------------------------
echo "============================================================"
echo "  TONG KET KIEM TRA"
echo "============================================================"

if [ "$errors" -eq 0 ]; then
  echo "  >> TAT CA CAC KIEM TRA DEU DAT!"
  echo "  >> Cau hinh Apache: OK"
  echo "  >> Chuyen huong HTTP -> HTTPS: OK"
  echo "  >> Truy cap HTTPS: OK"
else
  echo "  >> CO $errors LOI CAN XU LY!"
  echo "  >> Vui long doc lai ket qua tren de sua loi."
fi

echo "============================================================"
