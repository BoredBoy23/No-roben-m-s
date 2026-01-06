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
HISTORY_FILE="$LOG_DIR/last_dns.txt"
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
    printf "%35s${GREEN}Script version: 1.1.9${RESET}\n"
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

    # Priorizar último DNS conectado
    if [ -f "$HISTORY_FILE" ]; then
        LAST_USED=$(cat "$HISTORY_FILE")
        for i in "${!SERVERS[@]}"; do
            if [ "${SERVERS[$i]}" = "$LAST_USED" ]; then
                SERVERS=("${SERVERS[$i]}" "${SERVERS[@]:0:$i}" "${SERVERS[@]:$((i+1))}")
                break
            fi
        done
    fi

    while true; do
        for SERVER in "${SERVERS[@]}"; do
            clean_slipstream
            > "$LOG_FILE"

            clear
            echo -e "${CYAN}[*] Probando servidor:${RESET} $SERVER"
            separator

            # Lanzamos slipstream en background
            ./slipstream-client \
                --tcp-listen-port=5201 \
                --resolver="$SERVER" \
                --domain="$DOMAIN" \
                --keep-alive-interval=600 \
                --congestion-control=cubic \
                > "$LOG_FILE" 2>&1 &

            PID=$!
            CONNECTED=false
            TIMEOUT=0
            MAX_TIMEOUT=15   # segundos máximos para considerar que no conectó
            ANIM_IDX=0
            POINTS=("." ".." "...")
            
            # Animación + check de conexión
            while [ $TIMEOUT -lt $MAX_TIMEOUT ]; do
                echo -ne "${GRAY}Estableciendo Conexión${POINTS[$ANIM_IDX]}${RESET}\r"
                sleep 0.5
                ((ANIM_IDX=(ANIM_IDX+1)%3))
                ((TIMEOUT+=1))
                if grep -q "Connection confirmed" "$LOG_FILE"; then
                    CONNECTED=true
                    break
                fi
            done
            echo

            if $CONNECTED; then
                ACTIVE_DNS="$SERVER"
                echo "$ACTIVE_DNS" > "$HISTORY_FILE"
                clear
                echo -e "${GREEN}${BOLD}Servidor online ✅${RESET}"
                echo -e "${GREEN}DNS activo:${RESET} $ACTIVE_DNS"
                separator
                echo -e "${GRAY}Presione ENTER para volver al menú${RESET}"
                echo -ne "${CYAN}⏱ Tiempo conectado: ${RESET}0s\r"

                # Contador de tiempo + ENTER para salir
                SECONDS_CONNECTED=0
                stty -icanon -echo
                while true; do
                    sleep 1
                    SECONDS_CONNECTED=$((SECONDS_CONNECTED+1))
                    echo -ne "${CYAN}⏱ Tiempo conectado: ${RESET}${SECONDS_CONNECTED}s\r"
                    if read -t 0.1 -n 1 KEY; then
                        if [[ $KEY == "" ]]; then
                            stty sane
                            clean_slipstream
                            return
                        fi
                    fi

                    # Reconexión silenciosa si el proceso muere
                    if ! kill -0 $PID 2>/dev/null; then
                        stty sane
                        echo -e "\n${YELLOW}${BOLD}Conexión perdida, reconectando...${RESET}"
                        sleep 2
                        clean_slipstream
                        break
                    fi

                    # Reconexión si log indica error
                    if grep -qiE "connection closed|connection lost|EOF|timeout|error" "$LOG_FILE"; then
                        stty sane
                        echo -e "\n${YELLOW}${BOLD}Error detectado, reconectando...${RESET}"
                        sleep 2
                        clean_slipstream
                        break
                    fi
                done
            else
                echo -e "${RED}No se pudo conectar a $SERVER, probando siguiente...${RESET}"
                clean_slipstream
                sleep 1
            fi
        done
    done
}

####################################
# EJECUCIÓN INICIAL
####################################
check_server_on_start

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
