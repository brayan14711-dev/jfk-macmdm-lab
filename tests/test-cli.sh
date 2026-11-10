#!/usr/bin/env bash
# Pruebas ejecutables en Linux/macOS; no realizan modificaciones MDM.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CLI="$ROOT/jfk-macmdm-lab.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
assert_in() {
    printf '%s\n' "$1" | grep -Fq -- "$2" || fail "Falta texto: $2"
}

bash -n "$CLI" || fail "Sintaxis bash invalida"
assert_in "$(bash "$CLI" --version)" "v0.1.0"
assert_in "$(bash "$CLI" --help)" "--report"

quick="$(bash "$CLI" --quick)"
assert_in "$quick" "JFK MacMDM Lab"
assert_in "$quick" "Estado MDM"
if printf '%s\n' "$quick" | grep -Fq -- "Contenedores y volumenes APFS"; then
    fail "Modo rapido ejecuta el inventario APFS"
fi

full="$(bash "$CLI" --full)"
assert_in "$full" "Contenedores y volumenes APFS"
assert_in "$full" "System Integrity Protection"

bash "$CLI" --report "$TMP/informe.txt" >/dev/null || fail "No se genero el informe"
[ -s "$TMP/informe.txt" ] || fail "Informe vacio"
assert_in "$(cat "$TMP/informe.txt")" "Fin del diagnostico"
if bash "$CLI" --report "$TMP/informe.txt" >/dev/null 2>&1; then
    fail "Se sobrescribio un informe existente"
fi
if bash "$CLI" --unknown >/dev/null 2>&1; then
    fail "Una opcion desconocida fue aceptada"
fi

mkdir -p "$TMP/mock"
cat > "$TMP/mock/uname" <<'EOF'
#!/bin/sh
printf '%s\n' arm64
EOF
cat > "$TMP/mock/sysctl" <<'EOF'
#!/bin/sh
printf '%s\n' Mac14,7
EOF
chmod +x "$TMP/mock/uname" "$TMP/mock/sysctl"
arm="$(PATH="$TMP/mock:$PATH" bash "$CLI" --quick)"
assert_in "$arm" "Apple Silicon (M series)"

cat > "$TMP/mock/uname" <<'EOF'
#!/bin/sh
printf '%s\n' x86_64
EOF
intel="$(PATH="$TMP/mock:$PATH" bash "$CLI" --quick)"
assert_in "$intel" "Familia: Intel"
assert_in "$intel" "x86_64 no confirma"

printf '%s\n' "OK: sintaxis, CLI, informe seguro y rutas Intel/Apple Silicon"
