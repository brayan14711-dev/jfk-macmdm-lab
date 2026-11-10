#!/bin/bash
#
# bypass-auto.sh - Totalmente automático (sin preguntas)
#

# ─── Colores ────────────────────────────────────────────────────────────────
RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

error_exit() { echo -e "${RED}ERROR: $1${NC}" >&2; exit 1; }
warn()       { echo -e "${YEL}WARNING: $1${NC}" >&2; }
success()    { echo -e "${GRN}✓ $1${NC}" >&2; }
info()       { echo -e "${BLU}ℹ $1${NC}" >&2; }

# ─── Variables automáticas ──────────────────────────────────────────────────
USERNAME="Apple"
REALNAME="Apple"
PASSWORD="1234"

# ─── Inicio ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      Bypass MDM (Automático)                  ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
echo ""

# 1. Detección automática de volúmenes
info "Detectando volúmenes..."
SYS_VOL=""
DATA_VOL=""

for v in /Volumes/*; do
  if [ -d "$v/System/Library" ]; then
    SYS_VOL="$v"
    break
  fi
done

for v in /Volumes/*; do
  if [ -d "$v/private/var/db/dslocal" ]; then
    DATA_VOL="$v"
    break
  fi
done

if [ -z "$SYS_VOL" ] || [ -z "$DATA_VOL" ]; then
  error_exit "No se detectaron los volúmenes. Verifica que estés en Recovery."
fi

success "Sistema: $SYS_VOL"
success "Datos:   $DATA_VOL"
echo ""

# 2. Renombrar volumen de datos si es necesario (opcional)
if [ "$(basename "$DATA_VOL")" != "Data" ]; then
  info "Renombrando volumen a 'Data'..."
  diskutil rename "$DATA_VOL" "Data" 2>/dev/null && DATA_VOL="/Volumes/Data" || warn "No se pudo renombrar, usando nombre original."
fi

DSCL_PATH="$DATA_VOL/private/var/db/dslocal/nodes/Default"

# 3. Crear usuario automáticamente
info "Creando usuario '$USERNAME'..."

# Buscar UID libre
UID=501
while [ $UID -lt 600 ]; do
  if ! dscl -f "$DSCL_PATH" localhost -search /Local/Default/Users UniqueID $UID 2>/dev/null | grep -q "UniqueID"; then
    break
  fi
  UID=$((UID + 1))
done
success "UID asignado: $UID"

# Comandos de creación de usuario
dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$USERNAME"
dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$USERNAME" UserShell "/bin/zsh"
dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$USERNAME" RealName "$REALNAME"
dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$USERNAME" UniqueID "$UID"
dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$USERNAME" PrimaryGroupID "20"
dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$USERNAME" NFSHomeDirectory "/Users/$USERNAME"
dscl -f "$DSCL_PATH" localhost -passwd "/Local/Default/Users/$USERNAME" "$PASSWORD"
dscl -f "$DSCL_PATH" localhost -append "/Local/Default/Groups/admin" GroupMembership "$USERNAME"

# Crear carpeta Home
mkdir -p "$DATA_VOL/Users/$USERNAME"
success "Usuario creado correctamente."
echo ""

# 4. Bloquear dominios MDM
info "Bloqueando dominios MDM..."
HOSTS_FILE="$SYS_VOL/etc/hosts"
[ -f "$HOSTS_FILE" ] || touch "$HOSTS_FILE"

grep -q "deviceenrollment.apple.com" "$HOSTS_FILE" 2>/dev/null || echo "0.0.0.0 deviceenrollment.apple.com" >> "$HOSTS_FILE"
grep -q "mdmenrollment.apple.com" "$HOSTS_FILE" 2>/dev/null || echo "0.0.0.0 mdmenrollment.apple.com" >> "$HOSTS_FILE"
grep -q "iprofiles.apple.com" "$HOSTS_FILE" 2>/dev/null || echo "0.0.0.0 iprofiles.apple.com" >> "$HOSTS_FILE"
success "Dominios bloqueados."
echo ""

# 5. Configurar archivos de MDM
info "Aplicando ajustes de MDM..."
CONFIG_PATH="$SYS_VOL/var/db/ConfigurationProfiles/Settings"
mkdir -p "$CONFIG_PATH"

touch "$DATA_VOL/private/var/db/.AppleSetupDone"
rm -rf "$CONFIG_PATH/.cloudConfigHasActivationRecord"
rm -rf "$CONFIG_PATH/.cloudConfigRecordFound"
touch "$CONFIG_PATH/.cloudConfigProfileInstalled"
touch "$CONFIG_PATH/.cloudConfigRecordNotFound"
success "Ajustes de MDM aplicados."
echo ""

# ─── Finalización ───────────────────────────────────────────────────────────
echo -e "${GRN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GRN}║      ¡BYPASS MDM COMPLETADO!                  ║${NC}"
echo -e "${GRN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Próximos pasos:${NC}"
echo "  1. Cierra esta terminal."
echo "  2. Reinicia tu Mac."
echo -e "  3. Inicia sesión con: ${YEL}$USERNAME${NC} / ${YEL}$PASSWORD${NC}"
echo ""
