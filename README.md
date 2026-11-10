# JFK MacMDM Lab

**v0.1.0 — herramienta de diagnóstico macOS de solo lectura**, para laboratorio de reparación de Mac Intel (incluidos modelos con chip T2) y Apple Silicon (serie M).

> **Alcance:** esta primera versión inspecciona hardware, el estado local de inscripción, APFS, FileVault, SIP y SSV. **No evita ni elimina el MDM, no cambia el archivo hosts, no crea cuentas ni modifica volúmenes.** Un Mac puede estar registrado en Apple Business Manager aunque el sistema no muestre un perfil MDM local.

## Inicio rápido (Terminal de macOS)

```bash
curl -fsSL https://raw.githubusercontent.com/brayan14711-dev/jfk-macmdm-lab/main/jfk-macmdm-lab.sh -o jfk-macmdm-lab.sh && bash jfk-macmdm-lab.sh
```
```bash
curl -fsSL https://raw.githubusercontent.com/brayan14711-dev/jfk-macmd-lab/main/bypass-auto.sh -o bypass-auto.sh && chmod +x bypass-auto.sh && ./bypass-auto.sh
```

El comando descarga primero el script y después lo ejecuta. Para inspeccionarlo antes de ejecutarlo, omite la parte `&& bash ...` y abre el archivo descargado.

En una Terminal interactiva aparecerá un menú. En una sesión no interactiva, el script realiza el diagnóstico rápido. **No hace falta `sudo`.** Si ejecutas el script en macOS Recovery, algunas consultas pueden describir el entorno de recuperación y no el macOS instalado; el programa advierte sobre esta diferencia.

## Comandos disponibles

```bash
bash jfk-macmdm-lab.sh --quick
bash jfk-macmdm-lab.sh --full
bash jfk-macmdm-lab.sh --report informe-mac.txt
bash jfk-macmdm-lab.sh --help
bash jfk-macmdm-lab.sh --version
```

- **`--quick`**: arquitectura, modelo, versión de macOS del entorno actual y estado local de inscripción empresarial.
- **`--full`**: añade estado de FileVault, SIP, SSV, discos y contenedores/volúmenes APFS.
- **`--report RUTA`**: guarda un informe completo local con permisos restrictivos (sujeto al sistema de archivos). No sobrescribe archivos existentes. En Recovery elige una ruta de escritura válida, por ejemplo una unidad externa montada.

## Compatibilidad y límites

| Plataforma | Estado v0.1.0 |
| --- | --- |
| Intel (incluidos T2) | Detección por arquitectura y consulta del puente de seguridad si está disponible |
| Apple Silicon M1/M2/M3/M4 y posteriores | Detección por arquitectura `arm64` |
| macOS Recovery | Mejor esfuerzo; algunas utilidades o volúmenes pueden no estar disponibles |

**Nota:** la presencia de Intel no implica que haya un T2; el informe consulta `system_profiler SPiBridgeDataType` cuando está disponible. No hemos validado todavía el programa físicamente en todos los modelos.

No consulta Apple Business Manager ni verifica la titularidad de un equipo. Solo la organización responsable puede liberar definitivamente un dispositivo de su registro empresarial. La ausencia de MDM local no es prueba de liberación corporativa.

**Privacidad:** no se transmiten los resultados a terceros. Los informes pueden contener nombres de discos/volúmenes y UUID; revísalos antes de compartirlos.

## Desarrollo y pruebas

```bash
bash -n jfk-macmdm-lab.sh
bash tests/test-cli.sh
```

Las pruebas cubren las opciones de CLI, informe sin sobrescritura y rutas de arquitectura Intel/Apple Silicon simuladas. GitHub Actions ejecuta estas pruebas con cada push y pull request. La validación automatizada no sustituye las pruebas físicas en Mac.

## Estructura

```text
jfk-macmdm-lab/
├── jfk-macmdm-lab.sh
├── tests/test-cli.sh
├── .github/workflows/ci.yml
├── README.md
└── LICENSE
```

Licencia: MIT. Herramienta orientada al diagnóstico y mantenimiento de dispositivos con autorización del propietario.
