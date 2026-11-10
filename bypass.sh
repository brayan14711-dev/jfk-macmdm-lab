#!/bin/bash

# Define color codes
RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
PUR='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# Error handling function
error_exit() {
	echo -e "${RED}ERROR: $1${NC}" >&2
	exit 1
}

warn() { echo -e "${YEL}WARNING: $1${NC}"; }
success() { echo -e "${GRN}✓ $1${NC}"; }
info() { echo -e "${BLU}ℹ $1${NC}"; }

# Validation function for username
validate_username() {
	local username="$1"
	if [ -z "$username" ]; then echo "Username cannot be empty"; return 1; fi
	if [ ${#username} -gt 31 ]; then echo "Username too long (max 31)"; return 1; fi
	if ! [[ "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then echo "Letters, numbers, _ and - only"; return 1; fi
	if ! [[ "$username" =~ ^[a-zA-Z_] ]]; then echo "Must start with letter or _"; return 1; fi
	return 0
}

# Validation function for password
validate_password() {
	local password="$1"
	if [ -z "$password" ]; then echo "Password cannot be empty"; return 1; fi
	if [ ${#password} -lt 4 ]; then echo "Password too short (min 4)"; return 1; fi
	return 0
}

check_user_exists() {
	local dscl_path="$1"
	local username="$2"
	if dscl -f "$dscl_path" localhost -read "/Local/Default/Users/$username" 2>/dev/null; then
		return 0
	else
		return 1
	fi
}

find_available_uid() {
	local dscl_path="$1"
	local uid=501
	while [ $uid -lt 600 ]; do
		if ! dscl -f "$dscl_path" localhost -search /Local/Default/Users UniqueID $uid 2>/dev/null | grep -q "UniqueID"; then
			echo $uid
			return 0
		fi
		uid=$((uid + 1))
	done
	echo "501"
	return 1
}

# ─── DETECCIÓN DE VOLÚMENES (MODIFICADA PARA PORTUGUÉS/ESPAÑOL) ─────────────
detect_volumes() {
	local system_vol=""
	local data_vol=""

	info "Detecting system volumes..." >&2

	# Buscar el volumen del sistema comprobando si tiene la carpeta System/Library
	for vol in /Volumes/*; do
		if [ -d "$vol/System/Library" ]; then
			system_vol=$(basename "$vol")
			info "Found system volume: $system_vol" >&2
			break
		fi
	done

	# Buscar el volumen de datos comprobando si tiene la carpeta dslocal
	for vol in /Volumes/*; do
		if [ -d "$vol/private/var/db/dslocal" ]; then
			data_vol=$(basename "$vol")
			info "Found data volume: $data_vol" >&2
			break
		fi
	done

	# Validar findings
	if [ -z "$system_vol" ]; then
		error_exit "Could not detect system volume. Are you in Recovery?"
	fi

	if [ -z "$data_vol" ]; then
		error_exit "Could not detect data volume. Is FileVault blocking it?"
	fi

	echo "$system_vol|$data_vol"
}

# Detect volumes at startup
volume_info=$(detect_volumes)
system_volume=$(echo "$volume_info" | cut -d'|' -f1)
data_volume=$(echo "$volume_info" | cut -d'|' -f2)

# Display header
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Bypass MDM By Assaf Dori (Fixed by AI)       ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
success "System Volume: $system_volume"
success "Data Volume: $data_volume"
echo ""

# Prompt user for choice
PS3='Please enter your choice: '
options=("Bypass MDM from Recovery" "Reboot & Exit")
select opt in "${options[@]}"; do
	case $opt in
	"Bypass MDM from Recovery")
		echo ""
		echo -e "${YEL}═══════════════════════════════════════${NC}"
		echo -e "${YEL}  Starting MDM Bypass Process${NC}"
		echo -e "${YEL}═══════════════════════════════════════${NC}"
		echo ""

		# NO RENOMBRAMOS EL VOLUMEN (Evita el error de renombrar "Dados")
		
		# Validate critical paths
		info "Validating system paths..."

		system_path="/Volumes/$system_volume"
		data_path="/Volumes/$data_volume"

		if [ ! -d "$system_path" ]; then
			error_exit "System volume path does not exist: $system_path"
		fi

		if [ ! -d "$data_path" ]; then
			error_exit "Data volume path does not exist: $data_path"
		fi

		dscl_path="$data_path/private/var/db/dslocal/nodes/Default"
		if [ ! -d "$dscl_path" ]; then
			error_exit "Directory Services path does not exist: $dscl_path"
		fi

		success "All system paths validated"
		echo ""

		# Create Temporary User
		echo -e "${CYAN}Creating Temporary Admin User${NC}"
		echo -e "${NC}Press Enter to use defaults (recommended)${NC}"

		read -p "Enter Temporary Fullname (Default is 'Apple'): " realName
		realName="${realName:=Apple}"

		while true; do
			read -p "Enter Temporary Username (Default is 'Apple'): " username
			username="${username:=Apple}"

			if validation_msg=$(validate_username "$username"); then
				break
			else
				warn "$validation_msg"
				echo -e "${YEL}Please try again or press Ctrl+C to exit${NC}"
			fi
		done

		if check_user_exists "$dscl_path" "$username"; then
			warn "User '$username' already exists in the system"
			read -p "Do you want to use a different username? (y/n): " response
			if [[ "$response" =~ ^[Yy]$ ]]; then
				while true; do
					read -p "Enter a different username: " username
					if [ -z "$username" ]; then warn "Username cannot be empty"; continue; fi
					if validation_msg=$(validate_username "$username"); then
						if ! check_user_exists "$dscl_path" "$username"; then break; else warn "User '$username' also exists. Try another name."; fi
					else
						warn "$validation_msg"
					fi
				done
			else
				warn "Continuing with existing user '$username' (may cause conflicts)"
			fi
		fi

		while true; do
			read -p "Enter Temporary Password (Default is '1234'): " passw
			passw="${passw:=1234}"

			if validation_msg=$(validate_password "$passw"); then
				break
			else
				warn "$validation_msg"
				echo -e "${YEL}Please try again or press Ctrl+C to exit${NC}"
			fi
		done

		echo ""

		# Find available UID (CORREGIDO)
		info "Checking for available UID..."
		if available_uid=$(find_available_uid "$dscl_path"); then
			if [ "$available_uid" != "501" ]; then
				info "UID 501 is in use, using UID $available_uid instead"
			else
				info "Using UID 501"
			fi
		else
			error_exit "No available UID found between 501 and 599"
		fi
		success "Using UID: $available_uid"
		echo ""

		# Create User with error handling
		info "Creating user account: $username"

		if ! dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" 2>/dev/null; then
			error_exit "Failed to create user account"
		fi

		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UserShell "/bin/zsh" || warn "Failed to set user shell"
		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" RealName "$realName" || warn "Failed to set real name"
		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UniqueID "$available_uid" || warn "Failed to set UID"
		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" PrimaryGroupID "20" || warn "Failed to set GID"

		user_home="$data_path/Users/$username"
		if [ ! -d "$user_home" ]; then
			if mkdir -p "$user_home" 2>/dev/null; then
				success "Created user home directory"
			else
				error_exit "Failed to create user home directory: $user_home"
			fi
		else
			warn "User home directory already exists: $user_home"
		fi

		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" NFSHomeDirectory "/Users/$username" || warn "Failed to set home directory"

		if ! dscl -f "$dscl_path" localhost -passwd "/Local/Default/Users/$username" "$passw" 2>/dev/null; then
			error_exit "Failed to set user password"
		fi

		if ! dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username" 2>/dev/null; then
			error_exit "Failed to add user to admin group"
		fi

		success "User account created successfully"
		echo ""

		# Block MDM domains
		info "Blocking MDM enrollment domains..."
		hosts_file="$system_path/etc/hosts"
		if [ ! -f "$hosts_file" ]; then
			warn "Hosts file does not exist, creating it"
			touch "$hosts_file" || error_exit "Failed to create hosts file"
		fi

		grep -q "deviceenrollment.apple.com" "$hosts_file" 2>/dev/null || echo "0.0.0.0 deviceenrollment.apple.com" >>"$hosts_file"
		grep -q "mdmenrollment.apple.com" "$hosts_file" 2>/dev/null || echo "0.0.0.0 mdmenrollment.apple.com" >>"$hosts_file"
		grep -q "iprofiles.apple.com" "$hosts_file" 2>/dev/null || echo "0.0.0.0 iprofiles.apple.com" >>"$hosts_file"

		success "MDM domains blocked in hosts file"
		echo ""

		# Remove configuration profiles
		info "Configuring MDM bypass settings..."
		config_path="$system_path/var/db/ConfigurationProfiles/Settings"

		if [ ! -d "$config_path" ]; then
			if mkdir -p "$config_path" 2>/dev/null; then
				success "Created configuration directory"
			else
				warn "Could not create configuration directory"
			fi
		fi

		touch "$data_path/private/var/db/.AppleSetupDone" 2>/dev/null && success "Marked setup as complete" || warn "Could not mark setup as complete"

		rm -rf "$config_path/.cloudConfigHasActivationRecord" 2>/dev/null && success "Removed activation record" || info "No activation record to remove"
		rm -rf "$config_path/.cloudConfigRecordFound" 2>/dev/null && success "Removed cloud config record" || info "No cloud config record to remove"

		touch "$config_path/.cloudConfigProfileInstalled" 2>/dev/null && success "Created profile installed marker" || warn "Could not create profile marker"
		touch "$config_path/.cloudConfigRecordNotFound" 2>/dev/null && success "Created record not found marker" || warn "Could not create not found marker"

		echo ""
		echo -e "${GRN}╔═══════════════════════════════════════════════╗${NC}"
		echo -e "${GRN}║       MDM Bypass Completed Successfully!      ║${NC}"
		echo -e "${GRN}╚═══════════════════════════════════════════════╝${NC}"
		echo ""
		echo -e "${CYAN}Next steps:${NC}"
		echo -e "  1. Close this terminal window"
		echo -e "  2. Reboot your Mac"
		echo -e "  3. Login with username: ${YEL}$username${NC} and password: ${YEL}$passw${NC}"
		echo ""
		break
		;;
	"Reboot & Exit")
		echo ""
		info "Rebooting system..."
		reboot
		break
		;;
	*)
		echo -e "${RED}Invalid option $REPLY${NC}"
		;;
	esac
done
