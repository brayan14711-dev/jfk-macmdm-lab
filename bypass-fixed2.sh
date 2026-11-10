#!/bin/bash
#
# bypass-fixed2.sh - Ultra compatible con Recovery (Bash 3.2)
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

# ─── Detección de volúmenes ─────────────────────────────────────────────────
detect_volumes() {
  info "Detectando volúmenes..."
  local sys_mount=""
  local data_mount=""

  for v in /Volumes/*; do
    if [ -d "$v/System/Library" ]; then
      sys_mount="$v"
      break
    fi
  done

  for v in /Volumes/*; do
    if [ -d "$v/private/var/db/dslocal" ]; then
      data_mount="$v"
      break
    fi
  done

  if [ -z "$sys_mount" ] || [ -z "$data_mount" ]; then
    echo -e "${RED}ERROR: No se encontraron los volúmenes.${NC}" >&2
    echo "Asegúrate de estar en Recovery y que el disco de datos esté desbloqueado (FileVault)." >&2
    exit 1
  fi

  echo "$sys_mount|$data_mount"
}

# ─── Inicio del Script ──────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        Bypass MDM (Fixed 2)                   ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
echo ""

# Obtener volúmenes
VOL_INFO=$(detect_volumes)
SYS_VOL=$(echo "$VOL_INFO" | cut -d'|' -f1)
DATA_VOL=$(echo "$VOL_INFO" | cut -d'|' -f2)

success "Volumen sistema: $SYS_VOL"
success "Volumen datos:   $DATA_VOL"
echo ""

# ─── Menú Simple (Sin select, solo read) ────────────────────────────────────
echo "1) Iniciar Bypass MDM"
echo "2) Reiniciar la Mac"
echo "3) Salir"
read -p "Elige una opción (1, 2 o 3) y pulsa Enter: " OPCION

if [ "$OPCION" = "1" ]; then
    echo ""
    info "Iniciando proceso..."
    
    SYS_PATH="$SYS_VOL"
    DATA_PATH="$DATA_VOL"
    DSCL_PATH="$DATA_PATH/private/var/db/dslocal/nodes/Default"

    # Crear usuario
    echo "Pulsa Enter para usar los valores por defecto."
    read -p "Nombre de usuario (por defecto 'Apple'): " USERNAME
    USERNAME=${USERNAME:-Apple}
    
    read -p "Contraseña (por defecto '1234'): " PASSWORD
    PASSWORD=${PASSWORD:-1234}

    info "Creando usuario: $USERNAME"
    
    # Buscar UID libre (de 501 a 600)
    UID=501
    while [ $UID -lt 600 ]; do
        if ! dscl -f "$DSCL_PATH" localhost -search /Local/Default/Users UniqueID $UID 2>/dev/null | grep -q "UniqueID"; then
            break
        fi
        UID=$((UID + 1))
    done
    success "Usando UID: $UID"

    # Crear la cuenta
    dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$USERNAME"
    dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$USERNAME" UserShell "/bin/zsh"
    dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$USERNAME" RealName "Apple"
    dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$USERNAME" UniqueID "$UID"
    dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$USERNAME" PrimaryGroupID "20"
    dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$USERNAME" NFSHomeDirectory "/Users/$USERNAME"
    dscl -f "$DSCL_PATH" localhost -passwd "/Local/Default/Users/$USERNAME" "$PASSWORD"
    dscl -f "$DSCL_PATH" localhost -append "/Local/Default/Groups/admin" GroupMembership "$USERNAME"

    # Crear carpeta Home
    mkdir -p "$DATA_PATH/Users/$USERNAME"
    success "Usuario creado correctamente."

    # Bloquear dominios MDM
    info "Bloqueando dominios MDM..."
    HOSTS_FILE="$SYS_PATH/etc/hosts"
    echo "0.0.0.0 deviceenrollment.apple.com" >> "$HOSTS_FILE"
    echo "0.0.0.0 mdmenrollment.apple.com" >> "$HOSTS_FILE"
    echo "0.0.0.0 iprofiles.apple.com" >> "$HOSTS_FILE"
    success "Dominios bloqueados."

    # Configurar archivos de MDM
    info "Aplicando ajustes de MDM..."
    CONFIG_PATH="$SYS_PATH/var/db/ConfigurationProfiles/Settings"
    mkdir -p "$CONFIG_PATH"
    touch "$DATA_PATH/private/var/db/.AppleSetupDone"
    
    rm -rf "$CONFIG_PATH/.cloudConfigHasActivationRecord"
    rm -rf "$CONFIG_PATH/.cloudConfigRecordFound"
    
    touch "$CONFIG_PATH/.cloudConfigProfileInstalled"
    touch "$CONFIG_PATH/.cloudConfigRecordNotFound"
    
    echo ""
    echo -e "${GRN}═══════════════════════════════════════════════${NC}"
    echo -e "${GRN}   ¡BYPASS COMPLETADO CON ÉXITO!                ${NC}"
    echo -e "${GRN}═══════════════════════════════════════════════${NC}"
    echo ""
    echo "Usuario: $USERNAME"
    echo "Contraseña: $PASSWORD"
    echo ""
    echo "Ya puedes cerrar esta ventana y reiniciar la Mac."
    
elif [ "$OPCION" = "2" ]; then
    info "Reiniciando..."
    reboot
else
    info "Saliendo..."
    exit 0
fi
