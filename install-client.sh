#!/data/data/com.termux/files/usr/bin/bash
clear

####################################
# CONFIGURACIÓN
####################################
DOMAIN="h.p.2bd.net"
SERVER_STATUS="DESCONOCIDO"
ACTIVE_DNS="No conectado"

LOG_DIR="$HOME/.slipstream"
LOG_FILE="$LOG_DIR/slip.log"
LAST_DNS_FILE="$LOG_DIR/last_dns"
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

separator() {
    echo -e "${GRAY}────────────────────────────────────────${RESET}"
}

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
    printf "%35s${GREEN}Script version: 1.2.0${RESET}\n"
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
    echo
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

####################################
# CHEQUEO RÁPIDO DEL SERVIDOR
####################################
check_server_on_start() {
    clean_slipstream
    > "$LOG_FILE"

    ./slipstream-client \
        --tcp-listen-port=5201 \
        --resolver=1.1.1.1 \
        --domain="$DOMAIN" \
        --keep-alive-interval=600 \
        --congestion-control=cubic \
        > "$LOG_FILE" 2>&1 &

    PID=$!
    SERVER_STATUS="INACTIVO"

    for i in {1..4}; do
        grep -q "Connection confirmed" "$LOG_FILE" && {
            SERVER_STATUS="ACTIVO"
            break
        }
        sleep 1
    done

    kill $PID 2>/dev/null
    clean_slipstream
}

####################################
# ESTADO SERVIDOR
####################################
show_server_status() {
    if [ "$SERVER_STATUS" = "ACTIVO" ]; then
        echo -e "${GREEN}${BOLD}Servidor: ACTIVO  ✅${RESET}"
    else
        echo -e "${RED}${BOLD}Servidor: INACTIVO ❌${RESET}"
    fi
}

####################################
# INSTALADOR SLIPSTREAM AUTO
####################################
install_slipstream_auto() {
    clear
    ARCH=$(uname -m)

    echo -e "${CYAN}${BOLD}Detectando arquitectura...${RESET}"
    echo -e "${GRAY}$ARCH${RESET}\n"

    pkg install wget -y

    case "$ARCH" in
        aarch64|armv8a)
            wget -q -O setup.sh https://raw.githubusercontent.com/BoredBoy23/No-roben-m-s/main/setup.sh
            chmod +x setup.sh
            ./setup.sh
            ;;
        armv7l|armv7a|armv8l)
            wget -q -O setup32.sh https://raw.githubusercontent.com/BoredBoy23/No-roben-m-s/main/setup32.sh
            chmod +x setup32.sh
            ./setup32.sh
            ;;
        *)
            echo -e "${RED}Arquitectura no soportada${RESET}"
            ;;
    esac

    read -p "ENTER para volver al menú"
}

####################################
# CONEXIÓN AUTOMÁTICA INTELIGENTE
####################################
connect_auto() {
    local SERVERS=("$@")
    local PASSES=0
    local MAX_PASSES=2

    [ -f "$LAST_DNS_FILE" ] && SERVERS=($(cat "$LAST_DNS_FILE") "${SERVERS[@]}")

    while [ $PASSES -lt $MAX_PASSES ]; do

        [ $PASSES -eq 1 ] && {
            clear
            echo -e "${YELLOW}${BOLD}INTENTANDO DE NUEVO${RESET}"
            sleep 2
        }

        for SERVER in "${SERVERS[@]}"; do
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
                --congestion-control=cubic \
                > "$LOG_FILE" 2>&1 &

            PID=$!
            DOTS=0

            for i in {1..6}; do
                DOTS=$(( (DOTS % 3) + 1 ))
                printf "\r${GRAY}Estableciendo Conexión%.*s${RESET}" "$DOTS" "..."
                grep -q "Connection confirmed" "$LOG_FILE" && break
                sleep 1
            done
            echo

            if grep -q "Connection confirmed" "$LOG_FILE"; then
                echo "$SERVER" > "$LAST_DNS_FILE"
                ACTIVE_DNS="$SERVER"

                clear
                echo -e "${GREEN}${BOLD}Servidor online ✅${RESET}"
                echo -e "${GREEN}DNS activo:${RESET} $ACTIVE_DNS"
                separator

                START_TIME=$(date +%s)
                trap "clean_slipstream; trap - INT; return" INT

                while true; do
                    NOW=$(date +%s)
                    ELAPSED=$((NOW - START_TIME))
                    printf "\r⏱ Tiempo conectado: %02d:%02d" $((ELAPSED/60)) $((ELAPSED%60))
                    sleep 1

                    if ! kill -0 $PID 2>/dev/null || \
                       grep -qiE "ping timeout|connection closed|EOF|error" "$LOG_FILE"; then
                        echo -e "\n${YELLOW}Reconectando automáticamente...${RESET}"
                        sleep 2
                        clean_slipstream
                        connect_auto "${SERVERS[@]}"
                        return
                    fi

                    read -t 0.1 -r && {
                        clean_slipstream
                        return
                    }
                done
            fi

            clean_slipstream
        done

        PASSES=$((PASSES+1))
    done

    clear
    echo -e "${RED}${BOLD}Servidor offline ❌${RESET}"
    echo -e "${YELLOW}Solicite reiniciar el servidor${RESET}"
    read -p "ENTER para volver"
}

####################################
# INICIO
####################################
checking_screen
check_server_on_start
sleep 1

####################################
# MENÚ
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
