#!/bin/bash

# ==============================================================================
# Bypass MDM - Basado en Assaf Dori (assafdori.com) - Mejorado
# Adaptado para detección automática de volúmenes en cualquier idioma
# ==============================================================================

# Define color codes
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
# DETECCIÓN DE VOLÚMENES MEJORADA (A prueba de idiomas y Recovery)
# ==============================================================================
detect_volumes() {
	local system_vol=""
	local data_vol=""

	info "Detectando volúmenes (ignorando Recovery)..." >&2

	# Buscar el volumen del sistema y de datos, ignorando el disco virtual de Recovery
	for vol in /Volumes/*; do
		# Si es el disco de Recovery, lo saltamos
		if [[ "$vol" == *"Base System"* ]] || [[ "$vol" == *"Recovery"* ]]; then
			continue
		fi
		
		# Detectar Sistema (tiene /System/Library)
		if [ -d "$vol/System/Library" ]; then
			system_vol=$(basename "$vol")
		fi
		
		# Detectar Datos (tiene la base de datos de usuarios)
		if [ -d "$vol/private/var/db/dslocal" ]; then
			data_vol=$(basename "$vol")
		fi
	done

	# Validaciones
	if [ -z "$system_vol" ]; then
		error_exit "No se pudo detectar el volumen del sistema. Asegúrate de estar en Recovery y tener el disco montado."
	fi

	if [ -z "$data_vol" ]; then
		error_exit "No se pudo detectar el volumen de datos. ¿Está FileVault bloqueándolo? Ve a Utilidad de Discos y desbloquéalo."
	fi

	echo "$system_vol|$data_vol"
}

# ==============================================================================
# INICIO DEL SCRIPT
# ==============================================================================

# Detectar volúmenes
volume_info=$(detect_volumes)
system_volume=$(echo "$volume_info" | cut -d'|' -f1)
data_volume=$(echo "$volume_info" | cut -d'|' -f2)

# Mostrar cabecera
clear
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Bypass MDM - Assaf Dori (Mejorado)           ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
success "Volumen Sistema: $system_volume"
success "Volumen Datos:   $data_volume"
echo ""

# Menú simple para evitar cierres en Recovery
echo "1) Iniciar Bypass MDM"
echo "2) Reiniciar y salir"
echo "3) Salir sin reiniciar"
read -p "Elige una opción (1, 2 o 3): " opt

if [ "$opt" = "1" ]; then
	echo ""
	echo -e "${YEL}═══════════════════════════════════════${NC}"
	echo -e "${YEL}  Iniciando Proceso de Bypass MDM${NC}"
	echo -e "${YEL}═══════════════════════════════════════${NC}"
	echo ""

	system_path="/Volumes/$system_volume"
	data_path="/Volumes/$data_volume"
	dscl_path="$data_path/private/var/db/dslocal/nodes/Default"

	# Validar rutas
	[ -d "$system_path" ] || error_exit "Ruta del sistema no existe: $system_path"
	[ -d "$data_path" ]   || error_exit "Ruta de datos no existe: $data_path"
	[ -d "$dscl_path" ]   || error_exit "Base de datos no existe: $dscl_path"
	success "Rutas validadas"; echo

	# --- Crear Usuario ---
	echo -e "${CYAN}Creando Usuario Administrador Temporal${NC}"
	echo -e "${NC}Presiona Enter para usar los valores por defecto (recomendado)${NC}"

	read -p "Nombre completo (Default 'Apple'): " realName
	realName="${realName:=Apple}"

	read -p "Nombre de usuario (Default 'Apple'): " username
	username="${username:=Apple}"

	read -p "Contraseña (Default '1234'): " passw
	passw="${passw:=1234}"
	echo ""

	# Buscar UID disponible
	info "Buscando UID disponible..."
	available_uid=501
	while [ $available_uid -lt 600 ]; do
		if ! dscl -f "$dscl_path" localhost -search /Local/Default/Users UniqueID $available_uid 2>/dev/null | grep -q "UniqueID"; then
			break
		fi
		available_uid=$((available_uid + 1))
	done
	success "Usando UID: $available_uid"; echo

	# Crear la cuenta
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

elif [ "$opt" = "2" ]; then
	info "Reiniciando..."
	reboot
else
	info "Saliendo sin reiniciar..."
	exit 0
fi
