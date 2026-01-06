#!/data/data/com.termux/files/usr/bin/bash

clear

####################################
# CONFIGURACIÓN
####################################
DOMAIN="t.p.2bd.net"
SERVER_STATUS="DESCONOCIDO"
ACTIVE_DNS="No conectado"

LOG_DIR="$HOME/.slipstream"
LOG_FILE="$LOG_DIR/slip.log"
HIST_FILE="$LOG_DIR/last_dns.txt"
mkdir -p "$LOG_DIR"

DATA_SERVERS=(
"200.55.128.130:53"
"200.55.128.140:53"
"200.55.128.230:53"
"200.55.128.250:53"
)

WIFI_SERVERS=(
"181.225.231.120:53"
"181.225.231.110:53"
"181.225.233.40:53"
"181.225.233.30:53"
)

####################################
# COLORES
####################################
PURPLE="\e[38;5;93m"
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
CYAN="\e[36m"
GRAY="\e[90m"
BOLD="\e[1m"
RESET="\e[0m"

separator() { echo -e "${GRAY}────────────────────────────────────────${RESET}"; }

####################################
# BANNER
####################################
banner() {
    echo -e "${PURPLE}${BOLD}"
    echo "██╗   ██╗██╗██████╗ "
    echo "██║   ██║██║██╔══██╗"
    echo "██║   ██║██║██████╔╝"
    echo "╚██╗ ██╔╝██║██╔═══╝ "
    echo " ╚████╔╝ ██║██║     "
    echo "  ╚═══╝  ╚═╝╚═╝     "
    echo -e "${RESET}"
    printf "%35s${GREEN}Script version: 1.1.5${RESET}\n"
}

####################################
# PANTALLA DE VERIFICACIÓN
####################################
checking_screen() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "════════════════════════════════════════"
    echo "     VERIFICANDO ESTADO DEL SERVIDOR     "
    echo "════════════════════════════════════════"
    echo -e "${RESET}"
    echo -e "${GRAY}Espere unos segundos...${RESET}"
}

####################################
# LIMPIEZA
####################################
clean_slipstream() {
    pkill -f slipstream-client 2>/dev/null
    sleep 1
}

last_log_activity() {
    stat -c %Y "$LOG_FILE" 2>/dev/null
}

save_last_dns() {
    echo "$1" > "$HIST_FILE"
}

load_last_dns() {
    [ -f "$HIST_FILE" ] && echo "$(cat "$HIST_FILE")"
}

####################################
# CHEQUEO AUTOMÁTICO DEL SERVIDOR
####################################
check_server_on_start() {
    clean_slipstream
    > "$LOG_FILE"

    ./slipstream-client \
        --tcp-listen-port=5201 \
        --resolver=1.1.1.1 \
        --domain="$DOMAIN" \
        --keep-alive-interval=600 \
        > "$LOG_FILE" 2>&1 &

    PID=$!
    SERVER_STATUS="INACTIVO"

    for i in {1..8}; do
        grep -q "Connection confirmed" "$LOG_FILE" && { SERVER_STATUS="ACTIVO"; break; }
        grep -q "Connection closed" "$LOG_FILE" && break
        sleep 1
    done

    kill $PID 2>/dev/null
    clean_slipstream
}

####################################
# MOSTRAR ESTADO DEL SERVIDOR
####################################
show_server_status() {
    if [ "$SERVER_STATUS" = "ACTIVO" ]; then
        echo -e "${GREEN}${BOLD}Servidor: ACTIVO  ✅${RESET}"
    else
        echo -e "${RED}${BOLD}Servidor: INACTIVO ❌${RESET}"
    fi
}

####################################
# INSTALADOR AUTOMÁTICO
####################################
install_slipstream_auto() {
    clear
    ARCH=$(uname -m)
    pkg install wget -y

    case "$ARCH" in
        aarch64|armv8a)
            wget -q https://raw.githubusercontent.com/BoredBoy23/No-roben-m-s/main/setup.sh
            chmod +x setup.sh && ./setup.sh ;;
        armv7l|armv7a|armv8l)
            wget -q https://raw.githubusercontent.com/BoredBoy23/No-roben-m-s/main/setup32.sh
            chmod +x setup32.sh && ./setup32.sh ;;
        *)
            echo -e "${RED}Arquitectura no soportada${RESET}" ;;
    esac

    read -p "ENTER para volver"
}

####################################
# FLASH VISUAL RECONEXIÓN
####################################
flash_reconnect() {
    clear
    for i in {1..3}; do
        echo -e "${YELLOW}${BOLD}═══════════════════════════════${RESET}"
        echo -e "${YELLOW}${BOLD}     ⚡ RECONEXIÓN AUTOMÁTICA ⚡     ${RESET}"
        echo -e "${YELLOW}${BOLD}═══════════════════════════════${RESET}"
        sleep 0.3
        clear
        sleep 0.2
    done
}

####################################
# CONEXIÓN AUTOMÁTICA + WATCHDOG + HISTORIAL DNS
####################################
connect_auto() {
    local SERVERS=("$@")
    local LAST_DNS=$(load_last_dns)
    local ORDERED_SERVERS=()

    # Poner primero el último DNS bueno
    [ -n "$LAST_DNS" ] && ORDERED_SERVERS+=("$LAST_DNS")
    for S in "${SERVERS[@]}"; do
        [[ "$S" != "$LAST_DNS" ]] && ORDERED_SERVERS+=("$S")
    done

    for SERVER in "${ORDERED_SERVERS[@]}"; do
        clean_slipstream
        > "$LOG_FILE"

        clear
        echo -e "${CYAN}[*] Probando servidor:${RESET} $SERVER"
        separator

        ./slipstream-client \
            --tcp-listen-port=5201 \
            --resolver="$SERVER" \
            --domain="$DOMAIN" \
            --keep-alive-interval=600 \
            > "$LOG_FILE" 2>&1 &

        PID=$!
        sleep 3
        if ! grep -q "Connection confirmed" "$LOG_FILE"; then
            kill $PID 2>/dev/null
            continue
        fi

        # Conexión exitosa
        ACTIVE_DNS="$SERVER"
        save_last_dns "$SERVER"

        clear
        echo -e "${GREEN}${BOLD}Servidor online ✅${RESET}"
        echo -e "${GREEN}DNS activo:${RESET} $ACTIVE_DNS"
        separator
        echo -e "${GRAY}Ctrl + C para desconectar${RESET}"
        echo

        CONNECTED_TIME=0
        IDLE=0
        CHECK_INTERVAL=1
        HARD_LIMIT=90
        LAST_ACTIVITY=$(last_log_activity)

        while true; do
            sleep $CHECK_INTERVAL
            CONNECTED_TIME=$((CONNECTED_TIME + CHECK_INTERVAL))
            CUR=$(last_log_activity)

            [ "$CUR" = "$LAST_ACTIVITY" ] && IDLE=$((IDLE+CHECK_INTERVAL)) || { IDLE=0; LAST_ACTIVITY="$CUR"; }

            # Mostrar contador en tiempo real
            echo -ne "${CYAN}${BOLD}Tiempo conectado: $(printf '%02d:%02d:%02d' $((CONNECTED_TIME/3600)) $((CONNECTED_TIME%3600/60)) $((CONNECTED_TIME%60)))${RESET}\r"

            # Si cayó la conexión o error en log
            if ! kill -0 $PID 2>/dev/null || grep -qiE "connection closed|connection lost|timeout|error" "$LOG_FILE" || [ $IDLE -ge $HARD_LIMIT ]; then
                flash_reconnect
                clean_slipstream
                connect_auto "${SERVERS[@]}"
                return
            fi
        done
    done

    echo -e "${RED}${BOLD}Servidor offline ❌${RESET}"
    read -p "ENTER para volver"
}

####################################
# EJECUCIÓN INICIAL
####################################
checking_screen
check_server_on_start
sleep 1

####################################
# MENÚ PRINCIPAL
####################################
while true; do
    clear
    banner
    show_server_status
    separator

    echo " 1) Conectar en Datos Móviles"
    echo " 2) Conectar en WiFi"
    echo " 3) Instalar slipstream-client"
    echo " 0) Salir"

    separator
    read -p "Selecciona una opción: " opt

    case $opt in
        1) connect_auto "${DATA_SERVERS[@]}" ;;
        2) connect_auto "${WIFI_SERVERS[@]}" ;;
        3) install_slipstream_auto ;;
        0) clear; exit ;;
    esac
done
