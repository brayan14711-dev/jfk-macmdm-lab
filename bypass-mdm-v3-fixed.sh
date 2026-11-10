#!/bin/bash
#
# bypass-mdm-v3-fixed.sh
# Original: Assaf Dori (assafdori.com)
#

set -euo pipefail
IFS=$'\n\t'

# ─── Colores ────────────────────────────────────────────────────────────────
readonly RED='\033[1;31m'
readonly GRN='\033[1;32m'
readonly BLU='\033[1;34m'
readonly YEL='\033[1;33m'
readonly CYAN='\033[1;36m'
readonly NC='\033[0m'

# ─── Logging ────────────────────────────────────────────────────────────────
error_exit() { printf '%bERROR: %s%b\n' "$RED" "$1" "$NC" >&2; exit 1; }
warn()       { printf '%bWARNING: %s%b\n' "$YEL" "$1" "$NC" >&2; }
success()    { printf '%b✓ %s%b\n' "$GRN" "$1" "$NC" >&2; }
info()       { printf '%bℹ %s%b\n' "$BLU" "$1" "$NC" >&2; }

# ─── Trap ───────────────────────────────────────────────────────────────────
cleanup_on_interrupt() {
  printf '\n%bInterrumpido por el usuario.%b\n' "$YEL" "$NC" >&2
  exit 130
}
trap cleanup_on_interrupt INT TERM

# ─── Comprobaciones previas ─────────────────────────────────────────────────
require_root() {
  [ "$(id -u)" -eq 0 ] || error_exit "Este script debe ejecutarse como root (usa sudo)."
}

# ─── Validaciones ───────────────────────────────────────────────────────────
validate_username() {
  local u="$1"
  [ -n "$u" ]                        || { echo "El usuario no puede estar vacío" >&2; return 1; }
  [ "${#u}" -le 31 ]                 || { echo "Usuario demasiado largo (máx 31)" >&2; return 1; }
  [[ "$u" =~ ^[a-zA-Z0-9_-]+$ ]]     || { echo "Solo letras, números, _ y -" >&2; return 1; }
  [[ "$u" =~ ^[a-zA-Z_] ]]           || { echo "Debe empezar con letra o _" >&2; return 1; }
  return 0
}

validate_password() {
  local p="$1"
  [ -n "$p" ]        || { echo "La contraseña no puede estar vacía" >&2; return 1; }
  [ "${#p}" -ge 4 ]  || { echo "Contraseña demasiado corta (mín 4)" >&2; return 1; }
  return 0
}

prompt_validated() {
  local prompt="$1" default="$2" validator="$3"
  local value
  while true; do
    read -rp "$prompt" value
    value="${value:-$default}"
    if "$validator" "$value" 2>/dev/null; then
      printf '%s' "$value"
      return 0
    fi
    "$validator" "$value" >&2 || true
    warn "Inténtalo de nuevo o pulsa Ctrl+C para salir"
  done
}

# ─── Comprobaciones de sistema ──────────────────────────────────────────────
check_user_exists() {
  local dscl_path="$1" username="$2"
  dscl -f "$dscl_path" localhost -read "/Local/Default/Users/$username" >/dev/null 2>&1
}

# Busca UID libre, devuelve 0 si lo encontró, 1 si no.
find_available_uid() {
  local dscl_path="$1" uid=501
  while [ "$uid" -lt 1000 ]; do
    if ! dscl -f "$dscl_path" localhost -search /Local/Default/Users UniqueID "$uid" 2>/dev/null \
         | grep -q "UniqueID"; then
      printf '%s' "$uid"
      return 0
    fi
    uid=$((uid + 1))
  done
  return 1
}

# ─── Detección de volúmenes MEJORADA con diskutil ───────────────────────────
# Esto es lo que soluciona tu error. diskutil siempre sabe la verdad.
detect_volumes() {
  info "Detectando volúmenes usando diskutil..." >&2

  local sys_mount data_mount

  # Obtenemos el punto de montaje del volumen del sistema (/System/Library/CoreServices/SystemVersion.plist)
  # y del volumen de datos (/private/var/db).
  sys_mount=$(diskutil info -plist / 2>/dev/null | plutil -extract MountPoint raw - 2>/dev/null || true)
  if [ -z "$sys_mount" ] || [ "$sys_mount" = "/" ] && [ -d "/Volumes" ]; then
      # En Recovery, "/" no es el volumen real; usamos diskutil list para encontrarlo.
      # Buscamos el volumen que tenga /System/Library/CoreServices
      for v in /Volumes/*; do
         if [ -f "$v/System/Library/CoreServices/SystemVersion.plist" ]; then
            sys_mount="$v"
            break
         fi
      done
  fi

  # Obtenemos el volumen de datos buscando el que contenga /private/var/db
  for v in /Volumes/*; do
    if [ -d "$v/private/var/db/dslocal" ]; then
      data_mount="$v"
      break
    fi
  done

  # Si el sistema no se detectó por /System, buscamos cualquier volumen con /System/Library
  if [ -z "${sys_mount:-}" ]; then
      for v in /Volumes/*; do
         if [ -d "$v/System/Library" ]; then
            sys_mount="$v"
            break
         fi
      done
  fi

  # Validación final
  [ -n "${sys_mount:-}" ]  || error_exit "No se encontró el volumen del SISTEMA. ¿Estás en Recovery?" >&2
  [ -n "${data_mount:-}" ] || error_exit "No se encontró el volumen de DATOS. (Quizás está bloqueado por FileVault)" >&2

  info "Volumen sistema: $sys_mount" >&2
  info "Volumen datos:   $data_mount" >&2

  # Devolvemos los nombres base (ej. "mac" y "mac - Data")
  printf '%s\0%s' "$(basename "$sys_mount")" "$(basename "$data_mount")"
}

# ─── Main ───────────────────────────────────────────────────────────────────
main() {
  require_root

  local system_volume data_volume
  { IFS= read -r -d '' system_volume; IFS= read -r -d '' data_volume; } < <(detect_volumes)

  printf '\n%b╔═══════════════════════════════════════════════╗%b\n' "$CYAN" "$NC"
  printf '%b║  Bypass MDM By Assaf Dori (assafdori.com)    ║%b\n' "$CYAN" "$NC"
  printf '%b╚═══════════════════════════════════════════════╝%b\n\n' "$CYAN" "$NC"
  success "Volumen sistema: $system_volume"
  success "Volumen datos:   $data_volume"
  echo

  local PS3='Elige una opción: '
  local options=("Bypass MDM desde Recovery" "Reiniciar y salir" "Salir sin reiniciar")
  select opt in "${options[@]}"; do
    case $opt in
      "Bypass MDM desde Recovery")
        do_bypass "$system_volume" "$data_volume"
        break
        ;;
      "Reiniciar y salir")
        read -rp "¿Seguro que quieres reiniciar? (y/N): " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || { info "Cancelado"; continue; }
        info "Reiniciando..."; reboot; break
        ;;
      "Salir sin reiniciar")
        info "Saliendo."; exit 0
        ;;
      *) warn "Opción inválida: $REPLY" ;;
    esac
  done
}

do_bypass() {
  local system_volume="$1" data_volume="$2"
  local system_path data_path dscl_path

  printf '\n%b═══════════════════════════════════════%b\n' "$YEL" "$NC"
  printf '%b  Iniciando bypass de MDM%b\n' "$YEL" "$NC"
  printf '%b═══════════════════════════════════════%b\n\n' "$YEL" "$NC"

  if [ "$data_volume" != "Data" ]; then
    info "Renombrando volumen de datos a 'Data'..."
    if diskutil rename "/Volumes/$data_volume" "Data" 2>/dev/null; then
      success "Volumen renombrado"; data_volume="Data"
    else
      warn "No se pudo renombrar, continuando con: $data_volume"
    fi
  fi

  system_path="/Volumes/$system_volume"
  data_path="/Volumes/$data_volume"
  dscl_path="$data_path/private/var/db/dslocal/nodes/Default"

  [ -d "$system_path" ] || error_exit "No existe: $system_path"
  [ -d "$data_path" ]   || error_exit "No existe: $data_path"
  [ -d "$dscl_path" ]   || error_exit "No existe: $dscl_path"
  success "Rutas validadas"; echo

  # ── Crear usuario ────────────────────────────────────────────────────────
  info "Creando usuario administrador temporal"
  echo "Pulsa Enter para usar los valores por defecto"

  local realName username passw
  realName=$(prompt_validated "Nombre completo (por defecto 'Apple'): " "Apple" validate_username)

  while true; do
    username=$(prompt_validated "Usuario (por defecto 'Apple'): " "Apple" validate_username)
    if ! check_user_exists "$dscl_path" "$username"; then break; fi
    warn "El usuario '$username' ya existe. Elige otro."
  done

  passw=$(prompt_validated "Contraseña (por defecto '1234'): " "1234" validate_password)
  echo

  # ── UID (LÓGICA CORREGIDA) ───────────────────────────────────────────────
  local available_uid
  info "Buscando UID disponible..."
  if available_uid=$(find_available_uid "$dscl_path"); then
    if [ "$available_uid" = "501" ]; then
      info "Usando UID 501"
    else
      info "UID 501 ocupado, usando UID $available_uid"
    fi
    success "UID asignado: $available_uid"
  else
    error_exit "No hay ningún UID libre entre 501 y 999"
  fi
  echo

  # ── Crear cuenta ─────────────────────────────────────────────────────────
  info "Creando cuenta: $username"
  dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" \
    || error_exit "No se pudo crear el usuario"

  local attr
  for attr in \
    "UserShell /bin/zsh" \
    "RealName $realName" \
    "UniqueID $available_uid" \
    "PrimaryGroupID 20" \
    "NFSHomeDirectory /Users/$username"; do
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" $attr \
      || warn "Fallo al establecer: $attr"
  done

  local user_home="$data_path/Users/$username"
  [ -d "$user_home" ] && warn "El home ya existe: $user_home" \
                      || mkdir -p "$user_home" \
                      || error_exit "No se pudo crear el home: $user_home"

  dscl -f "$dscl_path" localhost -passwd "/Local/Default/Users/$username" -- "$passw" \
    || error_exit "No se pudo establecer la contraseña"

  dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username" \
    || error_exit "No se pudo añadir al grupo admin"

  success "Cuenta creada"; echo

  # ── Bloquear dominios MDM ────────────────────────────────────────────────
  info "Bloqueando dominios MDM..."
  local hosts_file="$system_path/etc/hosts"
  [ -f "$hosts_file" ] || { touch "$hosts_file" || error_exit "No se pudo crear hosts"; }

  local domain
  for domain in deviceenrollment.apple.com mdmenrollment.apple.com iprofiles.apple.com; do
    grep -q "$domain" "$hosts_file" 2>/dev/null \
      || printf '0.0.0.0 %s\n' "$domain" >> "$hosts_file"
  done
  success "Dominios bloqueados"; echo

  # ── Configuración MDM ────────────────────────────────────────────────────
  info "Configurando ajustes de bypass..."
  local config_path="$system_path/var/db/ConfigurationProfiles/Settings"
  [ -d "$config_path" ] || mkdir -p "$config_path" \
    || warn "No se pudo crear $config_path"

  touch "$data_path/private/var/db/.AppleSetupDone" 2>/dev/null \
    && success "Setup marcado como completo" \
    || warn "No se pudo marcar .AppleSetupDone"

  local f
  for f in .cloudConfigHasActivationRecord .cloudConfigRecordFound; do
    [ -n "$config_path" ] && rm -rf -- "${config_path:?}/$f" 2>/dev/null \
      && success "Eliminado: $f" || info "No existía: $f"
  done

  for f in .cloudConfigProfileInstalled .cloudConfigRecordNotFound; do
    touch "$config_path/$f" 2>/dev/null \
      && success "Creado: $f" || warn "No se pudo crear: $f"
  done

  echo
  printf '%b╔═══════════════════════════════════════════════╗%b\n' "$GRN" "$NC"
  printf '%b║      ¡Bypass de MDM completado con éxito!     ║%b\n' "$GRN" "$NC"
  printf '%b╚═══════════════════════════════════════════════╝%b\n\n' "$GRN" "$NC"
  info "Próximos pasos:"
  echo "  1. Cierra esta terminal"
  echo "  2. Reinicia el Mac"
  printf '  3. Inicia sesión con %s%s%s / %s%s%s\n\n' \
    "$YEL" "$username" "$NC" "$YEL" "$passw" "$NC"
}

main "$@"
