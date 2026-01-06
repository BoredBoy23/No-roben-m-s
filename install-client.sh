#!/data/data/com.termux/files/usr/bin/bash

clear

####################################
# CONFIGURACIÓN
####################################
DOMAIN="t.p.2bd.net"
SERVER_STATUS="DESCONOCIDO"
ACTIVE_DNS="No conectado"
HIST_FILE="$HOME/.slipstream/last_dns.txt"

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
    printf "%35s${GREEN}Script version: 1.1.9${RESET}\n"
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
# FLASH RECONNECT
####################################
flash_reconnect() {
    for i in {1..3}; do
        echo -ne "${YELLOW}${BOLD}Reconectando${RESET}   \r"
        sleep 0.3
        echo -ne "${YELLOW}${BOLD}Reconectando.${RESET}  \r"
        sleep 0.3
        echo -ne "${YELLOW}${BOLD}Reconectando..${RESET} \r"
        sleep 0.3
        echo -ne "${YELLOW}${BOLD}Reconectando...${RESET}\r"
        sleep 0.3
    done
    echo
}

####################################
# CONEXIÓN AUTOMÁTICA + WATCHDOG + CONTADOR + ENTER
####################################
connect_auto() {
    local SERVERS=("$@")
    local PASSES=0
    local MAX_PASSES=2

    # Priorizar último DNS conectado
    if [ -f "$HIST_FILE" ]; then
        LAST_DNS=$(cat "$HIST_FILE")
        SERVERS=("$LAST_DNS" "${SERVERS[@]/$LAST_DNS/}")
    fi

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

            # Animación de Estableciendo Conexión...
            for dots in {1..3}; do
                echo -ne "${CYAN}Estableciendo Conexión${'.' * $dots}   \r"
                sleep 0.5
            done
            echo

            ./slipstream-client \
                --tcp-listen-port=5201 \
                --resolver="$SERVER" \
                --domain="$DOMAIN" \
                --keep-alive-interval=600 \
                --congestion-control=cubic \
                > "$LOG_FILE" 2>&1 &

            PID=$!
            ACTIVE_DNS="$SERVER"

            # Guardar último DNS bueno
            echo "$ACTIVE_DNS" > "$HIST_FILE"

            CONNECTED_TIME=0
            IDLE=0
            SILENCE_LIMIT=40
            HARD_LIMIT=70
            CHECK_INTERVAL=1
            LAST_ACTIVITY=$(last_log_activity)
            stty -echo -icanon time 0 min 0

            while true; do
                sleep $CHECK_INTERVAL
                CONNECTED_TIME=$((CONNECTED_TIME+CHECK_INTERVAL))
                CUR=$(last_log_activity)
                [ "$CUR" = "$LAST_ACTIVITY" ] && IDLE=$((IDLE+CHECK_INTERVAL)) || { IDLE=0; LAST_ACTIVITY="$CUR"; }

                # Mostrar contador y texto separados
                echo -ne "${CYAN}${BOLD}⏱️ Tiempo conectado: $(printf '%02d:%02d:%02d' $((CONNECTED_TIME/3600)) $((CONNECTED_TIME%3600/60)) $((CONNECTED_TIME%60)))${RESET}\n"
                echo -ne "${GRAY}Presione ENTER para volver al menú${RESET}\r"

                # ENTER detectado
                if read -r -t 0.1 KEY && [ "$KEY" = "" ]; then
                    stty sane
                    clean_slipstream
                    return
                fi

                # Reconexión inteligente
                if ! kill -0 $PID 2>/dev/null || grep -qiE "connection closed|connection lost|timeout|ping timeout|error" "$LOG_FILE" || [ $IDLE -ge $HARD_LIMIT ]; then
                    echo
                    stty sane
                    flash_reconnect
                    clean_slipstream
                    connect_auto "${SERVERS[@]}"
                    return
                fi
            done

        done
        PASSES=$((PASSES+1))
    done

    stty sane
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
