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
        --congestion-control=cubic \
        > "$LOG_FILE" 2>&1 &

    PID=$!
    SERVER_STATUS="INACTIVO"

    for i in {1..8}; do
        if grep -q "Connection confirmed" "$LOG_FILE"; then
            SERVER_STATUS="ACTIVO"
            break
        fi

        if grep -q "Connection closed" "$LOG_FILE"; then
            break
        fi

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
# INSTALADOR AUTOMÁTICO (32 / 64 bits)
####################################
install_slipstream_auto() {
    clear
    ARCH=$(uname -m)

    echo -e "${CYAN}${BOLD}Detectando arquitectura del dispositivo...${RESET}"
    echo
    echo -e "${GRAY}Arquitectura detectada:${RESET} $ARCH"
    echo

    pkg install wget -y

    case "$ARCH" in
        aarch64|armv8a)
            echo -e "${GREEN}Sistema ARM 64 bits detectado${RESET}"
            rm -f setup.sh
            wget https://raw.githubusercontent.com/BoredBoy23/No-roben-m-s/refs/heads/main/setup.sh
            chmod +x setup.sh
            ./setup.sh
            ;;
        armv7l|armv7a|armv8l)
            echo -e "${YELLOW}Sistema ARM 32 bits detectado${RESET}"
            rm -f setup32.sh
            wget https://raw.githubusercontent.com/BoredBoy23/No-roben-m-s/refs/heads/main/setup32.sh
            chmod +x setup32.sh
            ./setup32.sh
            ;;
        *)
            echo -e "${RED}Arquitectura no soportada: $ARCH${RESET}"
            ;;
    esac

    echo
    read -p "ENTER para volver al menú"
}

####################################
# CONEXIÓN AUTOMÁTICA + WATCHDOG
####################################
connect_auto() {
    local SERVERS=("$@")
    local PASSES=0
    local MAX_PASSES=2

    while [ $PASSES -lt $MAX_PASSES ]; do

        [ $PASSES -eq 1 ] && {
            clear
            echo -e "${YELLOW}${BOLD}"
            echo "════════════════════════════════════════"
            echo "        INTENTANDO DE NUEVO"
            echo "════════════════════════════════════════"
            echo -e "${RESET}"
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
                > >(tee -a "$LOG_FILE") 2>&1 &

            PID=$!

            for i in {1..3}; do
                grep -q "Connection confirmed" "$LOG_FILE" && break
                sleep 1
            done

            if grep -q "Connection confirmed" "$LOG_FILE"; then
                ACTIVE_DNS="$SERVER"
                clear
                echo -e "${GREEN}${BOLD}Servidor online ✅${RESET}"
                echo -e "${GREEN}DNS activo:${RESET} $ACTIVE_DNS"
                separator
                echo -e "${GRAY}Ctrl + C para desconectar${RESET}"

                LAST_ACTIVITY=$(last_log_activity)
                IDLE=0

                while true; do
                    sleep 2
                    CUR=$(last_log_activity)

                    [ "$CUR" = "$LAST_ACTIVITY" ] && IDLE=$((IDLE+2)) || { IDLE=0; LAST_ACTIVITY="$CUR"; }

                    if [ $IDLE -ge 10 ] || ! kill -0 $PID 2>/dev/null; then
                        echo -e "${YELLOW}${BOLD}Reconectando automáticamente...${RESET}"
                        sleep 2
                        clean_slipstream
                        connect_auto "${SERVERS[@]}"
                        return
                    fi
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
