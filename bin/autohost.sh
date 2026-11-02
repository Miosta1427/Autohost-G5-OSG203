#!/usr/bin/env bash
# AutoHost UI v2. Administrative operations stay in the existing backend scripts.
set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")/.." && pwd)" || exit 1
SCRIPT_FILE="$SCRIPT_DIR/bin/autohost.sh"
mode=${1:-auto}
if (( $# > 1 )); then printf 'Chi nhan mot tuy chon. Xem --help.\n' >&2; exit 2; fi
case "$mode" in
    --help)
        printf 'AutoHost UI v2\n\n'
        printf 'autohost                  Mo cua so terminal rieng tren Ubuntu Desktop.\n'
        printf 'autohost --here           Dung terminal hien tai (can root).\n'
        printf 'autohost --window         Bat buoc mo cua so moi.\n'
        printf 'autohost --preview        Chi xem menu, khong thao tac.\n'
        printf 'autohost --preview-splash Chi xem hieu ung mo dau, khong thao tac.\n'
        printf '\nNO_COLOR=1: tat mau; AUTOHOST_ASCII=1: khung don gian.\n'
        printf 'AUTOHOST_NO_SPLASH=1: bo qua hieu ung tai.\n'
        exit 0 ;;
    auto|--here|--window|--preview|--preview-splash) ;;
    *) printf 'Tuy chon khong hop le: %s\n' "$mode" >&2; exit 2 ;;
esac

open_window() {
    local desktop_user='' desktop_uid='' session_id _ key value
    local session_type session_active session_remote session_user session_display
    local display_value='' wayland_value='' xauth_value='' entry runtime
    local -a prefix=() gui_env=() candidates=() displays=() child

    command -v gnome-terminal >/dev/null 2>&1 || return 1
    # Do not send an SSH user's window to someone else's local desktop.
    [[ -z ${SSH_CONNECTION:-}${SSH_TTY:-} ]] || return 1
    if (( EUID != 0 )); then
        [[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]] || return 1
        desktop_uid=$EUID
        display_value=${DISPLAY:-}
        wayland_value=${WAYLAND_DISPLAY:-}
        xauth_value=${XAUTHORITY:-}
    else
        # A root shell may have lost its desktop environment after sudo -i.
        # Select only an active, local graphical session, never an SFTP session.
        command -v loginctl >/dev/null 2>&1 || return 1
        command -v runuser >/dev/null 2>&1 || return 1
        while read -r session_id _; do
            [[ -n $session_id ]] || continue
            session_type='' session_active='' session_remote='' session_user='' session_display=''
            while IFS='=' read -r key value; do
                case "$key" in
                    Type) session_type=$value ;;
                    Active) session_active=$value ;;
                    Remote) session_remote=$value ;;
                    Name) session_user=$value ;;
                    Display) session_display=$value ;;
                esac
            done < <(loginctl show-session "$session_id" -p Type -p Active -p Remote -p Name -p Display 2>/dev/null)
            if [[ $session_type == x11 || $session_type == wayland ]] &&
               [[ $session_active == yes && $session_remote == no && -n $session_user && $session_user != root ]]; then
                candidates+=("$session_user")
                displays+=("$session_display")
            fi
        done < <(loginctl list-sessions --no-legend --no-pager 2>/dev/null)
        if [[ -n ${SUDO_USER:-} && $SUDO_USER != root ]]; then
            for entry in "${!candidates[@]}"; do
                if [[ ${candidates[entry]} == "$SUDO_USER" ]]; then
                    desktop_user=$SUDO_USER; display_value=${displays[entry]}; break
                fi
            done
        elif (( ${#candidates[@]} == 1 )); then
            desktop_user=${candidates[0]}; display_value=${displays[0]}
        fi
        [[ -n $desktop_user ]] || return 1
        desktop_uid=$(id -u "$desktop_user") || return 1
        [[ $desktop_uid =~ ^[0-9]+$ && $desktop_uid != 0 ]] || return 1
        prefix=(runuser -u "$desktop_user" --)
        runtime="/run/user/$desktop_uid"
        [[ -S $runtime/bus ]] || return 1
        # Read specific values as data. Never source/eval the user's environment.
        while IFS='=' read -r key value; do
            case "$key" in
                DISPLAY) display_value=$value ;;
                WAYLAND_DISPLAY) wayland_value=$value ;;
                XAUTHORITY) xauth_value=$value ;;
            esac
        done < <("${prefix[@]}" env XDG_RUNTIME_DIR="$runtime" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus" \
            systemctl --user show-environment 2>/dev/null)
    fi
    runtime="/run/user/$desktop_uid"
    [[ -n $display_value$wayland_value && -S $runtime/bus ]] || return 1
    gui_env=(env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY
        "XDG_RUNTIME_DIR=$runtime" "DBUS_SESSION_BUS_ADDRESS=unix:path=$runtime/bus")
    [[ -z $display_value ]] || gui_env+=("DISPLAY=$display_value")
    [[ -z $wayland_value ]] || gui_env+=("WAYLAND_DISPLAY=$wayland_value")
    [[ -z $xauth_value ]] || gui_env+=("XAUTHORITY=$xauth_value")
    # The terminal is owned by the desktop user; only the menu uses sudo.
    # Fixed shell code + positional argument keeps paths with spaces safe.
    child=(bash -c '
        sudo -- bash "$1" --here
        result=$?
        if (( result != 0 )); then
            printf "\nAutoHost dung voi ma %s. Nhan Enter de dong cua so..." "$result"
            IFS= read -r _
        fi
        exit "$result"
    ' autohost-window "$SCRIPT_FILE")
    "${prefix[@]}" "${gui_env[@]}" gnome-terminal --window \
        --title='AutoHost | G5 - OSG203' --geometry=110x34 --working-directory=/ \
        -- "${child[@]}"
}

if [[ $mode == auto || $mode == --window ]]; then
    if open_window; then exit 0; fi
    if [[ $mode == --window ]]; then
        printf 'Khong mo duoc cua so moi. Hay chay tu Terminal tren Ubuntu Desktop.\n' >&2
        printf 'Kiem tra gnome-terminal; hoac dung: sudo autohost --here\n' >&2
        exit 1
    fi
    printf 'Khong co cua so do hoa kha dung; dung terminal hien tai.\n' >&2
    mode=--here
fi
if [[ $mode == --here ]] && (( EUID != 0 )); then
    exec sudo -- bash "$SCRIPT_FILE" --here
fi

# Preview is read-only and works without the AutoHost backend installed.
SITES_DB='/etc/autohost/sites.csv'
if [[ $mode == --here ]]; then
    source "$SCRIPT_DIR/conf/autohost.conf" || exit 1
    : "${SITES_DB:?Thieu SITES_DB trong autohost.conf}"
fi

RESET='' BOLD='' CYAN='' BLUE='' GREEN='' YELLOW='' RED='' DIM='' BG=''
if [[ -t 1 && ${TERM:-dumb} != dumb && ! ${NO_COLOR+x} ]]; then
    BG=$'\033[48;5;234m'; RESET=$'\033[0m'"$BG"$'\033[38;5;252m'
    BOLD=$'\033[1m'; DIM=$'\033[38;5;245m'; CYAN=$'\033[38;5;81m'
    BLUE=$'\033[38;5;60m'; GREEN=$'\033[38;5;114m'
    YELLOW=$'\033[38;5;221m'; RED=$'\033[38;5;203m'
fi
TL='╭' TR='╮' BL='╰' BR='╯' H='─' V='│'
if [[ ${AUTOHOST_ASCII:-0} == 1 || ${LC_ALL:-${LC_CTYPE:-${LANG:-C}}} != *[Uu][Tt][Ff]* ]]; then
    TL='+'; TR='+'; BL='+'; BR='+'; H='-'; V='|'
fi
WIDTH=76 COLS=80 ROWS=24 LEFT=0 SCREEN_ACTIVE=0
choice='' keep='' username='' domain=''

measure() {
    local size=''
    COLS=80 ROWS=24
    if [[ -t 1 ]]; then size=$(stty size 2>/dev/null) || :; fi
    if [[ $size =~ ^([0-9]+)[[:space:]]+([0-9]+)$ ]]; then
        ROWS=${BASH_REMATCH[1]}; COLS=${BASH_REMATCH[2]}
    fi
    (( COLS < 10 )) && COLS=10
    (( ROWS < 6 )) && ROWS=6
    WIDTH=$((COLS-4))
    (( WIDTH > 84 )) && WIDTH=84
    LEFT=$(((COLS-WIDTH)/2))
    return 0
}
cleanup() {
    if (( SCREEN_ACTIVE )); then printf '\033[0m\033[?25h\033[?1049l'; fi
}
start_screen() {
    if [[ -t 0 && -t 1 && ${TERM:-dumb} != dumb ]]; then
        printf '\033[?1049h%b\033[2J\033[H' "$RESET"
        SCREEN_ACTIVE=1
        trap cleanup EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM
        trap 'exit 129' HUP
    fi
}
screen() {
    measure
    if [[ -t 1 && ${TERM:-dumb} != dumb ]]; then
        printf '%b\033[2J\033[H' "$RESET"
    fi
}
notice() {
    local color=$1 tag=$2 message=$3
    printf '\n%b[%s]%b %s\n' "$color" "$tag" "$RESET" "$message"
}
line() {
    local left=$1 right=$2 i
    printf '%*s%b%s' "$LEFT" '' "$BLUE" "$left"
    for ((i=0; i<WIDTH-2; i++)); do printf '%s' "$H"; done
    printf '%s%b\n' "$right" "$RESET"
}
row() {
    local content=$1 style=${2:-} inner=$((WIDTH-4)) padding
    (( inner < 1 )) && inner=1
    if (( ${#content} > inner )); then content="${content:0:inner}"; fi
    padding=$((inner-${#content}))
    printf '%*s%b%s%b %b%s%b%*s %b%s%b\n' \
        "$LEFT" '' "$BLUE" "$V" "$RESET" "$style" "$content" "$RESET" \
        "$padding" '' "$BLUE" "$V" "$RESET"
}
center() {
    local content=$1 style=${2:-} pad max=$((COLS-2))
    content=${content:0:max}
    pad=$(((COLS-${#content})/2))
    printf '%*s%b%s%b\n' "$pad" '' "$style" "$content" "$RESET"
}
header() {
    local title=$1
    screen
    printf '\n'
    center 'G5  /  OSG203' "$DIM"
    center "$title" "$BOLD$CYAN"
    printf '\n'
}
service_status() {
    local unit=$1 state
    if ! command -v systemctl >/dev/null 2>&1; then printf 'unknown'; return; fi
    state=$(systemctl is-active "$unit" 2>/dev/null) || :
    case "$state" in
        active|inactive|failed|activating|deactivating|reloading) printf '%s' "$state" ;;
        *) printf 'unknown' ;;
    esac
}
dashboard() {
    local total='--' counts active='--' host apache ssh_state health_style
    host=$(hostname 2>/dev/null) || host='unknown'
    apache=$(service_status apache2)
    ssh_state=$(service_status ssh)
    if [[ -r $SITES_DB ]]; then
        if counts=$(awk -F, 'NR>1 && NF>=4 {n++; if($4=="active") a++}
            END {print n+0, a+0}' "$SITES_DB"); then
            read -r total active <<< "$counts"
        fi
    fi
    health_style=$YELLOW
    [[ $apache == active && $ssh_state == active ]] && health_style=$GREEN
    [[ $apache == failed || $ssh_state == failed ]] && health_style=$RED
    header 'CONTROL CENTER'
    line "$TL" "$TR"
    row "SERVER  $host" "$BOLD"
    row "Apache: $apache   /   SSH: $ssh_state" "$health_style"
    row "Website: $total   /   Trang thai active trong CSV: $active" "$DIM"
    line "$BL" "$BR"
    printf '\n'
    line "$TL" "$TR"
    if (( COLS >= 88 )); then
        row ''
        row '  [1] TAO WEBSITE                        [2] DANH SACH WEBSITE' "$BOLD$CYAN"
        row '      User, thu muc va VirtualHost            Xem cac website da tao' "$DIM"
        row ''
        row '  [3] SAO LUU WEBSITE                     [4] SFTP / WEBDAV' "$BOLD$CYAN"
        row '      Luu du lieu va cau hinh                 Quan ly truy cap file' "$DIM"
        row ''
        row '  [5] XOA WEBSITE                        [6] THOAT' "$BOLD$YELLOW"
        row '      Backup va xac nhan truoc                Dong cua so AutoHost' "$DIM"
        row ''
    else
        row '[1] TAO WEBSITE' "$BOLD$CYAN"
        row '[2] DANH SACH WEBSITE' "$BOLD$CYAN"
        row '[3] SAO LUU WEBSITE' "$BOLD$CYAN"
        row '[4] SFTP / WEBDAV' "$BOLD$CYAN"
        row '[5] XOA WEBSITE' "$BOLD$YELLOW"
        row '[6] THOAT' "$DIM"
    fi
    line "$BL" "$BR"
    printf '\n'
    center 'Chon so 1-6 va nhan Enter' "$DIM"
    printf '\n'
}

ask() {
    local variable=$1 label=$2
    printf '%b > %s%b ' "$CYAN" "$label" "$RESET"
    IFS= read -r "${variable?}"
}
pause_menu() {
    printf '\n%bNhan Enter de ve menu...%b ' "$DIM" "$RESET"
    IFS= read -r _ || exit 0
}
run_command() {
    local rc
    printf '\n%b--- KET QUA THAO TAC ---%b\n\n' "$DIM" "$RESET"
    "$@"
    rc=$?
    if (( rc == 0 )); then
        notice "$GREEN" OK 'Lenh da ket thuc. Xem ket qua chi tiet phia tren.'
    else
        notice "$RED" LOI "Lenh dung voi ma $rc. Doc thong bao phia tren."
    fi
    # Keep the menu usable after a backend error; never retry a mutation.
    return 0
}
show_sites() {
    header 'DANH SACH WEBSITE'
    if [[ ! -r $SITES_DB ]]; then
        notice "$YELLOW" CHUA_CO "Khong doc duoc $SITES_DB."
        return
    fi
    if ! awk -F, 'NR>1 && NF>=4 {found=1} END {exit !found}' "$SITES_DB"; then
        notice "$YELLOW" TRONG 'Chua co website nao trong danh sach.'
        return
    fi
    # Full fields remain visible even when the terminal is narrow.
    awk -F, 'NR>1 && NF>=4 {
        printf "\n  %s\n    User: %s    Status: %s\n    Created: %s\n",
            $2,$1,$4,$3
    }' "$SITES_DB"
    printf '\n%bTrang thai CSV khong thay cho kiem tra HTTP truc tiep.%b\n' "$DIM" "$RESET"
}
access_menu() {
    local selected username domain
    header 'QUAN LY TRUY CAP'
    line "$TL" "$TR"
    row '[1] Cau hinh SFTP Chroot' "$CYAN"
    row '[2] Bat WebDAV / dat lai mat khau WebDAV' "$CYAN"
    row '[0] Quay lai'
    line "$BL" "$BR"
    printf '\nSFTP dung mat khau Linux; WebDAV dung mat khau rieng.\n'
    ask selected 'Chon [0-2]:' || exit 0
    case "$selected" in
        0) return ;;
        1)
            # Support the packaged backend and the classroom access.sh.
            if [[ -f $SCRIPT_DIR/bin/access.sh ]]; then
                ask domain 'Domain can cau hinh SFTP:' || exit 0
                run_command bash "$SCRIPT_DIR/bin/access.sh" sftp "$domain"
            else
                run_command bash -c '
                    source "$1/conf/autohost.conf" || exit 1
                    source "$1/lib/common.sh" || exit 1
                    source "$1/lib/access.sh" || exit 1
                    setup_sftp
                ' _ "$SCRIPT_DIR"
            fi ;;
        2)
            ask username 'Username cua site:' || exit 0
            ask domain 'Domain cua site:' || exit 0
            printf '\nBan se dat/doi MAT KHAU WEBDAV cho site nay.\n'
            if [[ -f $SCRIPT_DIR/bin/access.sh ]]; then
                if ! awk -F, -v u="$username" -v d="$domain" '
                    NR>1 && $1==u && $2==d {n++} END {exit(n!=1)}
                ' "$SITES_DB"; then
                    notice "$RED" LOI 'Username va domain khong khop danh sach site.'
                    return
                fi
                run_command bash "$SCRIPT_DIR/bin/access.sh" webdav "$domain"
            else
                run_command bash -c '
                    source "$1/conf/autohost.conf" || exit 1
                    source "$1/lib/common.sh" || exit 1
                    source "$1/lib/access.sh" || exit 1
                    setup_webdav "$2" "$3"
                ' _ "$SCRIPT_DIR" "$username" "$domain"
            fi ;;
        *) notice "$YELLOW" CHON_LAI 'Chi nhap 0, 1 hoac 2.' ;;
    esac
}


# A ~3-second presentation animation, not a service readiness check.
show_splash() {
    local i top height logo_line barwidth filled empty bar rest percent
    local old_cols=0 old_rows=0 progress_row=1 logo_style=0
    local -a logo=(
        ' ███  █   █ █████  ███  █   █  ███   ████ █████'
        '█   █ █   █   █   █   █ █   █ █   █ █       █  '
        '█████ █   █   █   █   █ █████ █   █  ███    █  '
        '█   █ █   █   █   █   █ █   █ █   █     █   █  '
        '█   █  ███    █    ███  █   █  ███  ████    █  '
    )
    [[ ${AUTOHOST_NO_SPLASH:-0} == 1 || ! -t 0 || ! -t 1 || ${TERM:-dumb} == dumb ]] && return 0
    printf '\033[?25l'
    for ((i=0; i<=30; i++)); do
        measure
        if (( old_cols != COLS || old_rows != ROWS )); then
            printf '%b\033[2J\033[H' "$RESET"
            height=13; logo_style=1
            if (( COLS < 54 || ROWS < 18 )) || [[ $H == '-' ]]; then
                height=7; logo_style=0
            fi
            top=$(((ROWS-height)/2+1))
            (( top < 1 )) && top=1
            printf '\033[%d;1H' "$top"
            center 'G5  /  OSG203' "$DIM"
            printf '\n'
            if (( logo_style )); then
                for logo_line in "${logo[@]}"; do center "$logo_line" "$BOLD$CYAN"; done
            else
                center 'A U T O H O S T' "$BOLD$CYAN"
            fi
            printf '\n'
            if (( logo_style )); then
                center 'WEBSITE HOSTING MANAGER' "$BOLD"
                center 'SFTP  /  WebDAV  /  Backup  /  Apache' "$DIM"
                printf '\n'
                progress_row=$((top+11))
            else
                progress_row=$((top+4))
            fi
            old_cols=$COLS; old_rows=$ROWS
        fi
        barwidth=$((COLS-16))
        (( barwidth > 36 )) && barwidth=36
        (( barwidth < 1 )) && barwidth=1
        filled=$((i*barwidth/30)); empty=$((barwidth-filled)); percent=$((i*100/30))
        printf -v bar '%*s' "$filled" ''
        printf -v rest '%*s' "$empty" ''
        if [[ $H == '-' ]]; then bar=${bar// /#}; rest=${rest// /-};
        else bar=${bar// /━}; rest=${rest// /─}; fi
        printf '\033[%d;1H\033[2K%*s%b%s%b%s%b  %3d%%' \
            "$progress_row" "$(((COLS-barwidth-6)/2))" '' "$CYAN" "$bar" "$BLUE" "$rest" "$RESET" "$percent"
        printf '\033[%d;1H\033[2K' "$((progress_row+1))"
        if (( i == 30 )); then center 'HOAN TAT' "$GREEN";
        else center 'Dang mo giao dien...' "$DIM"; fi
        if (( i < 30 )); then sleep 0.09 || return 1; fi
    done
    # Keep 100% visible briefly, then remove the entire logo before the menu.
    sleep 0.3 || return 1
    printf '\033[?25h'
    screen
}

if [[ $mode == --preview ]]; then dashboard; printf '\033[0m'; exit 0; fi
start_screen
show_splash || exit 130
if [[ $mode == --preview-splash ]]; then
    dashboard
    printf '\nNhan Enter de dong ban xem truoc... '
    IFS= read -r _ || :
    exit 0
fi

while true; do
    dashboard
    ask choice 'Chon chuc nang [1-6]:' || exit 0
    case "$choice" in
        1)
            header 'TAO WEBSITE MOI'
            ask username 'Username (vi du kh002):' || exit 0
            ask domain 'Domain (vi du kh002.example.test):' || exit 0
            run_command bash "$SCRIPT_DIR/bin/addsite.sh" "$username" "$domain" ;;
        2) show_sites ;;
        3)
            header 'SAO LUU WEBSITE'
            ask domain 'Domain can backup:' || exit 0
            run_command bash "$SCRIPT_DIR/bin/backup.sh" "$domain" ;;
        4) access_menu ;;
        5)
            header 'XOA WEBSITE'
            notice "$YELLOW" CHU_Y 'Lenh xoa se yeu cau nhap lai domain de xac nhan.'
            ask domain 'Domain can xoa:' || exit 0
            ask keep 'Giu du lieu web va WebDAV? [y/N]:' || exit 0
            case "$keep" in
                y|Y)
                    printf '\nGiu file duoi quyen root; user va cau hinh site van bi xoa.\n'
                    run_command bash "$SCRIPT_DIR/bin/delsite.sh" "$domain" --keep-data ;;
                n|N|'')
                    printf '\nDu lieu se bi xoa sau khi backup va xac nhan thanh cong.\n'
                    run_command bash "$SCRIPT_DIR/bin/delsite.sh" "$domain" ;;
                *) notice "$YELLOW" HUY 'Lua chon khong hop le; chua goi lenh xoa.' ;;
            esac ;;
        6) printf '\n%bDa thoat AutoHost.%b\n\n' "$CYAN" "$RESET"; exit 0 ;;
        *) notice "$YELLOW" CHON_LAI 'Hay nhap mot so tu 1 den 6.' ;;
    esac
    pause_menu
done
