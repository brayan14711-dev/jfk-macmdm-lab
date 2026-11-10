#!/bin/bash
# JFK MacMDM Lab - herramientas de diagnostico de solo lectura
# Compatible con Bash 3.2 (macOS Recovery). No altera el estado MDM.
set -u

VERSION="0.1.0"
PROJECT="JFK MacMDM Lab"

line() { printf '%s\n' "$*"; }
section() { printf '\n--- %s ---\n' "$1"; }
available() { command -v "$1" >/dev/null 2>&1; }

run_readonly() {
    local label="$1"
    shift
    section "$label"
    if ! available "$1"; then
        line "No disponible en este entorno: $1"
        return 0
    fi
    local output code
    output="$("$@" 2>&1)"
    code=$?
    if [ -n "$output" ]; then
        printf '%s\n' "$output"
    else
        line "(La consulta no devolvio datos)"
    fi
    if [ "$code" -ne 0 ]; then
        line "Aviso: la consulta termino con codigo $code; no se modifico nada."
    fi
    return 0
}

recovery_context() {
    local info=""
    if available diskutil; then
        info="$(diskutil info / 2>/dev/null || true)"
    fi
    case "$info" in
        *"Base System"*|*"Recovery"*)
            line "Entorno: posiblemente macOS Recovery"
            line "IMPORTANTE: los comandos pueden describir Recovery, no el macOS instalado."
            ;;
        *)
            line "Entorno: macOS o entorno no identificado."
            line "Si usas Recovery, los estados pueden reflejar Recovery y no el volumen instalado."
            ;;
    esac
}

header() {
    line "============================================================"
    line "  $PROJECT v$VERSION"
    line "  Diagnostico no invasivo - Intel T2 / Apple Silicon"
    line "============================================================"
    line "Fecha local: $(date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || date)"
    recovery_context
    line ""
    line "Este programa NO elude ni elimina MDM, Activation Lock o firmware locks."
}

hardware() {
    section "Equipo"
    local arch model
    arch="$(uname -m 2>/dev/null || printf 'desconocida')"
    model="no disponible"
    if available sysctl; then
        model="$(sysctl -n hw.model 2>/dev/null || printf 'no disponible')"
    fi
    line "Modelo: $model"
    line "Arquitectura: $arch"
    case "$arch" in
        arm64)
            line "Familia: Apple Silicon (M series)"
            line "Nota: la version exacta del chip requiere consulta de hardware."
            ;;
        x86_64)
            line "Familia: Intel"
            line "Nota: x86_64 no confirma por si solo la presencia de T2."
            ;;
        *)
            line "Familia: no identificada; puede ser un entorno de pruebas."
            ;;
    esac
    run_readonly "macOS del entorno actual" sw_vers
    if [ "$arch" = "x86_64" ]; then
        run_readonly "Puente de seguridad Intel (si existe)" system_profiler SPiBridgeDataType -detailLevel mini
    fi
}

enrollment() {
    section "Inscripcion empresarial"
    line "La salida siguiente es solo el estado local. No confirma liberacion de Apple Business."
    run_readonly "Estado MDM / inscripcion automatizada" profiles status -type enrollment
}

protection() {
    run_readonly "FileVault (entorno actual)" fdesetup status
    run_readonly "System Integrity Protection" csrutil status
    run_readonly "Authenticated Root / SSV (si esta disponible)" csrutil authenticated-root status
}

storage() {
    section "Almacenamiento APFS"
    line "Inventario del sistema: verifica pares System/Data por rol y contenedor."
    line "No se monta, desbloquea, renombra ni modifica ningun volumen."
    run_readonly "Discos y particiones" diskutil list
    run_readonly "Contenedores y volumenes APFS" diskutil apfs list
}

footer() {
    section "Interpretacion y seguridad"
    line "- Una inscripcion local ausente NO garantiza que el equipo no este asignado en ABM/ASM."
    line "- Un Mac en Recovery puede mostrar datos del entorno de recuperacion."
    line "- No se han ejecutado escrituras de sistema ni comandos de bypass."
    line "- El informe puede incluir nombres de volumenes y UUID: revisalo antes de compartir."
    line "Fin del diagnostico."
}

quick() {
    header
    hardware
    enrollment
    footer
}

full() {
    header
    hardware
    enrollment
    protection
    storage
    footer
}

usage() {
    cat <<'USAGE'
JFK MacMDM Lab v0.1.0 - diagnostico local de solo lectura

Uso:
  bash jfk-macmdm-lab.sh             Menu interactivo si hay terminal
  bash jfk-macmdm-lab.sh --quick     Hardware y estado local MDM
  bash jfk-macmdm-lab.sh --full      Incluye APFS, FileVault, SIP y SSV
  bash jfk-macmdm-lab.sh --report ARCHIVO.txt
                                    Genera un informe local (sin sobrescribir)
  bash jfk-macmdm-lab.sh --version
  bash jfk-macmdm-lab.sh --help

Compatible con Intel (incluido T2) y Apple Silicon (serie M).
No elimina ni elude perfiles MDM o el registro en Apple Business Manager.
No necesita sudo. No envia informacion a servicios externos.
USAGE
}

save_report() {
    local path="$1"
    if [ -z "$path" ]; then
        line "Error: indica la ruta para el informe." >&2
        return 2
    fi
    if [ -e "$path" ]; then
        line "Error: el archivo ya existe; no se sobrescribira: $path" >&2
        return 2
    fi
    local body
    body="$(full)"
    if (umask 077; set -C; printf '%s\n' "$body" > "$path"); then
        line "Informe creado: $path"
        line "El archivo es local. Revisalo antes de compartirlo."
        return 0
    fi
    line "Error: no se pudo crear el archivo: $path" >&2
    return 1
}

menu() {
    while true; do
        line ""
        line "===== JFK MacMDM Lab ====="
        line "1) Diagnostico rapido"
        line "2) Diagnostico completo (APFS, T2, MDM, FileVault)"
        line "3) Guardar informe completo"
        line "4) Ayuda"
        line "0) Salir"
        printf 'Selecciona una opcion: '
        IFS= read -r choice || return 0
        case "$choice" in
            1) quick ;;
            2) full ;;
            3)
                printf 'Ruta del informe (ejemplo: informe-mac.txt): '
                IFS= read -r path || return 0
                save_report "$path"
                ;;
            4) usage ;;
            0) return 0 ;;
            *) line "Opcion no valida." ;;
        esac
    done
}

main() {
    case "${1:-}" in
        --quick) quick ;;
        --full) full ;;
        --report)
            if [ "$#" -ne 2 ]; then
                line "Uso: --report ARCHIVO.txt" >&2
                return 2
            fi
            save_report "$2"
            ;;
        --version) line "$PROJECT v$VERSION" ;;
        --help|-h) usage ;;
        "")
            if [ -t 0 ]; then
                menu
            else
                quick
            fi
            ;;
        *)
            line "Opcion desconocida: $1" >&2
            usage >&2
            return 2
            ;;
    esac
}
main "$@"
