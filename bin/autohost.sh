#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$SCRIPT_DIR/conf/autohost.conf" || exit 1
source "$SCRIPT_DIR/lib/common.sh" || exit 1

check_root || exit 1

# Bao loi nhung van giu menu de nguoi dung thao tac tiep.
run_command() {
    if "$@"; then
        :
    else
        echo
        echo "Lenh khong hoan tat. Hay xem thong bao loi phia tren."
    fi
}

while true; do
    echo
    echo "========================================"
    echo "         AUTOHOST - G5 - OSG203"
    echo "========================================"
    echo "1. Tao website"
    echo "2. Xem danh sach website"
    echo "3. Sao luu website"
    echo "4. Cau hinh SFTP / WebDAV"
    echo "5. Xoa website"
    echo "6. Thoat"
    echo "========================================"

    read -r -p "Chon [1-6]: " choice || exit 0

    case "$choice" in
        1)
            read -r -p "Username khach hang: " username || exit 0
            read -r -p "Domain website: " domain || exit 0

            run_command bash "$SCRIPT_DIR/bin/addsite.sh" \
                "$username" "$domain"
            ;;

        2)
            if [[ -f $SITES_DB ]]; then
                printf '\n%-16s %-38s %s\n' \
                    "USERNAME" "DOMAIN" "STATUS"

                awk -F, '
                    NR > 1 {
                        printf "%-16s %-38s %s\n", $1, $2, $4
                    }
                ' "$SITES_DB"
            else
                echo "Chua co file quan ly site: $SITES_DB"
            fi
            ;;

        3)
            read -r -p "Domain can backup: " domain || exit 0

            run_command bash "$SCRIPT_DIR/bin/backup.sh" \
                "$domain"
            ;;

        4)
            echo
            echo "1. Cau hinh SFTP cho nhom sftpusers"
            echo "2. Bat WebDAV / doi mat khau WebDAV cho mot site"
            echo "0. Quay lai"

            read -r -p "Chon [0-2]: " access_choice || exit 0

            case "$access_choice" in
                1)
                    run_command bash -c '
                        source "$1/lib/access.sh" || exit 1
                        setup_sftp
                    ' _ "$SCRIPT_DIR"
                    ;;

                2)
                    read -r -p "Username cua site: " username || exit 0
                    read -r -p "Domain cua site: " domain || exit 0

                    run_command bash -c '
                        source "$1/lib/access.sh" || exit 1
                        setup_webdav "$2" "$3"
                    ' _ "$SCRIPT_DIR" "$username" "$domain"
                    ;;

                0)
                    continue
                    ;;

                *)
                    echo "Lua chon khong hop le."
                    ;;
            esac
            ;;

        5)
            read -r -p "Domain can xoa: " domain || exit 0
            read -r -p "Giu lai du lieu web va WebDAV? [y/N]: " keep \
                || exit 0

            if [[ $keep == y || $keep == Y ]]; then
                run_command bash "$SCRIPT_DIR/bin/delsite.sh" \
                    "$domain" --keep-data
            else
                run_command bash "$SCRIPT_DIR/bin/delsite.sh" \
                    "$domain"
            fi
            ;;

        6)
            echo "Da thoat menu AutoHost."
            exit 0
            ;;

        *)
            echo "Vui long nhap mot so tu 1 den 6."
            ;;
    esac

    echo
    read -r -p "Nhan Enter de quay lai menu..." pause || exit 0
done
