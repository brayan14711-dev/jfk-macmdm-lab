#!/bin/bash

# ==============================================================================
# Bypass MDM - Versión Intuitiva y Amigable
# Basado en Assaf Dori
# ==============================================================================

# ─── Colores ───
RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
CYAN='\033[1;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Funciones de Interfaz ───
error_exit() { echo -e "\n${RED}❌ ERROR: $1${NC}\n" >&2; exit 1; }
warn()       { echo -e "${YEL}⚠️  ADVERTENCIA: $1${NC}"; }
success()    { echo -e "${GRN}✅ $1${NC}"; }
info()       { echo -e "${BLU}ℹ️  $1${NC}"; }

# Barra de progreso visual simple
step() {
    echo -e "\n${CYAN}▶ PASO $1: $2${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
}

# ─── Variables Fijas ───
USERNAME="Apple"
REALNAME="Apple"
PASSWORD="1234"

# ─── Bienvenida ───
clear
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════╗"
echo "║                                                  ║"
echo "║        🍎  BYPASS MDM - ASISTENTE AUTOMÁTICO     ║"
echo "║                                                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "Este asistente configurará tu Mac para saltar el bloqueo"
echo -e "de MDM (Gestión de Dispositivos) de forma automática."
echo -e "No necesitas hacer nada más, solo esperar a que termine."
echo ""
sleep 2

# ─── PASO 1: Detección de Discos ───
step "1/5" "Buscando los discos de tu Mac..."
SYS_VOL=""
DATA_VOL=""

for v in /Volumes/*; do
    if [[ "$v" == *"Base System"* ]] || [[ "$v" == *"Recovery"* ]]; then continue; fi
    if [ -d "$v/System/Library" ]; then SYS_VOL="$v"; fi
    if [ -d "$v/private/var/db/dslocal" ]; then DATA_VOL="$v"; fi
done

if [ -z "$SYS_VOL" ] || [ -z "$DATA_VOL" ]; then
    error_exit "No se pudieron encontrar los discos. Asegúrate de estar en Recovery y que FileVault esté desbloqueado."
fi

sleep 1
success "Disco del Sistema detectado: $(basename "$SYS_VOL")"
success "Disco de Datos detectado:    $(basename "$DATA_VOL")"
sleep 1

# ─── PASO 2: Preparación del Sistema ───
step "2/5" "Preparando el sistema para crear el usuario..."
info "Desactivando la protección del sistema (SIP)..."
csrutil disable 2>/dev/null
sleep 1
success "Protección desactivada correctamente."

# ─── PASO 3: Creación del Usuario ───
step "3/5" "Creando tu nuevo usuario administrador..."
DSCL_PATH="$DATA_VOL/private/var/db/dslocal/nodes/Default"

# Comprobar si ya existe
if dscl -f "$DSCL_PATH" localhost -read "/Local/Default/Users/$USERNAME" >/dev/null 2>&1; then
    warn "El usuario '$USERNAME' ya existía. Se usará ese mismo."
else
    # Buscar UID libre (501 a 999)
    AVAILABLE_UID=501
    while [ $AVAILABLE_UID -lt 999 ]; do
        if ! dscl -f "$DSCL_PATH" localhost -search /Local/Default/Users UniqueID $AVAILABLE_UID 2>/dev/null | grep -q "UniqueID"; then break; fi
        AVAILABLE_UID=$((AVAILABLE_UID + 1))
    done
    
    info "Configurando cuenta '$USERNAME' con el ID: $AVAILABLE_UID"
    
    dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$USERNAME"
    dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$USERNAME" UserShell "/bin/zsh"
    dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$USERNAME" RealName "$REALNAME"
    dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$USERNAME" UniqueID "$AVAILABLE_UID"
    dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$USERNAME" PrimaryGroupID "20"
    dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$USERNAME" NFSHomeDirectory "/Users/$USERNAME"
    dscl -f "$DSCL_PATH" localhost -passwd "/Local/Default/Users/$USERNAME" "$PASSWORD"
    dscl -f "$DSCL_PATH" localhost -append "/Local/Default/Groups/admin" GroupMembership "$USERNAME"
    
    mkdir -p "$DATA_VOL/Users/$USERNAME"
    sleep 1
    success "Usuario creado y añadido a administradores."
fi

# ─── PASO 4: Bloqueo de MDM ───
step "4/5" "Bloqueando los servidores de MDM de Apple..."
HOSTS_FILE="$SYS_VOL/etc/hosts"
[ -f "$HOSTS_FILE" ] || touch "$HOSTS_FILE"
cp "$HOSTS_FILE" "${HOSTS_FILE}.bak"
info "Creada copia de seguridad del archivo de red (hosts.bak)"

DOMAINS=("deviceenrollment.apple.com" "mdmenrollment.apple.com" "iprofiles.apple.com")
for domain in "${DOMAINS[@]}"; do
    if grep -q "$domain" "$HOSTS_FILE"; then
        echo -e "   - ${YEL}$domain${NC} ya estaba bloqueado."
    else
        echo "0.0.0.0 $domain" >> "$HOSTS_FILE"
        echo -e "   - ${GRN}$domain${NC} bloqueado correctamente."
    fi
done
sleep 1

# ─── PASO 5: Limpieza y Parches Finales ───
step "5/5" "Aplicando parches finales de configuración..."
CONFIG_PATH="$SYS_VOL/var/db/ConfigurationProfiles/Settings"
mkdir -p "$CONFIG_PATH"

touch "$DATA_VOL/private/var/db/.AppleSetupDone"
rm -rf "$CONFIG_PATH/.cloudConfigHasActivationRecord"
rm -rf "$CONFIG_PATH/.cloudConfigRecordFound"
touch "$CONFIG_PATH/.cloudConfigProfileInstalled"
touch "$CONFIG_PATH/.cloudConfigRecordNotFound"

info "Sincronizando datos con el disco duro (no apagues la Mac)..."
sync
sleep 2
success "Todos los cambios guardados de forma segura."

# ─── Pantalla Final ───
clear
echo -e "${GRN}${BOLD}"
echo "╔══════════════════════════════════════════════════╗"
echo "║                                                  ║"
echo "║          🎉 ¡BYPASS COMPLETADO CON ÉXITO!        ║"
echo "║                                                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BOLD}Tus nuevas credenciales de acceso son:${NC}"
echo -e "  👤 Usuario:    ${YEL}${BOLD}$USERNAME${NC}"
echo -e "  🔑 Contraseña: ${YEL}${BOLD}$PASSWORD${NC}"
echo ""
echo -e "${CYAN}¿Qué debes hacer ahora?${NC}"
echo -e "  1. Anota o memoriza estas credenciales."
echo -e "  2. La Mac se reiniciará automáticamente en ${YEL}15 segundos${NC}."
echo -e "  3. Cuando encienda, inicia sesión con el usuario y contraseña."
echo ""
echo -e "${YEL}👉 Si necesitas cancelar el reinicio para leer algo, pulsa Ctrl+C.${NC}"
echo ""

# Cuenta regresiva visual
for i in {15..1}; do
    echo -ne "\rReiniciando en ${RED}${BOLD}$i${NC} segundos... "
    sleep 1
done

echo -e "\n\n¡Hasta luego! 👋"
sync
reboot
