#!/usr/bin/env bash
# dump_pstrees.sh
# Uso:
#   ./dump_pstrees.sh [ruta_a_memoria] [salida_txt]
# Ejemplo:
#   ./dump_pstrees.sh win-dump.mem pstrees.txt
#
# Variables opcionales:
#   VOL=vol  # comando de volatility3 (puedes poner ruta absoluta si quieres)

set -euo pipefail

VOL="${VOL:-vol}"
DUMP="${1:-win-dump.mem}"
OUT="${2:-pstrees.txt}"

if [[ ! -r "$DUMP" ]]; then
  echo "[-] No puedo leer el archivo de memoria: $DUMP" >&2
  exit 1
fi

# Limpiar/crear salida que luego se usara para generar el archivo de salida
: > "$OUT"

echo "[*] Obteniendo lista de procesos (windows.pslist)..." | tee -a "$OUT"

# Extraer PIDs de la tabla. 
# Filtramos líneas que empiezan con número (PID).
readarray -t PIDS < <(
  "$VOL" -f "$DUMP" windows.pslist 2>/dev/null \
    | awk '/^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[A-Za-z0-9_.-]+/ {print $1}' \
    | sort -n | uniq
)

# Guardar TODO el resultado de windows.pslist en el archivo de salida
{
  echo
  echo "==== Salida completa de windows.pslist ($(date -u +'%Y-%m-%d %H:%M:%S UTC')) ===="
  "$VOL" -f "$DUMP" windows.pslist 2>&1
  echo "===================================================================="
  echo
} >> "$OUT"

# Fallback a psscan si no se consiguió nada con pslist
if [[ ${#PIDS[@]} -eq 0 ]]; then
  echo "[*] pslist no devolvió PIDs. Probando windows.psscan..." | tee -a "$OUT"
  readarray -t PIDS < <(
    "$VOL" -f "$DUMP" windows.psscan 2>/dev/null \
      | awk '/^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[A-Za-z0-9_.-]+/ {print $1}' \
      | sort -n | uniq
  )
fi

if [[ ${#PIDS[@]} -eq 0 ]]; then
  echo "[-] No se encontraron PIDs. ¿Es válida la imagen o faltan símbolos/capas?" | tee -a "$OUT"
  exit 2
fi

echo "[*] Se encontraron ${#PIDS[@]} procesos. Generando pstree por PID..." | tee -a "$OUT"

for pid in "${PIDS[@]}"; do
  {
    echo "================================================================================"
    echo "ejecutando:"
    echo "$VOL" -f "$DUMP" windows.cmdline --pid "$pid"
    echo "--------------------------------------------------------------------------------"
    echo
    echo "PID: $pid  |  Fecha: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
    echo "================================================================================"
    echo
    "$VOL" -f "$DUMP" windows.pstree --pid "$pid"
  } >> "$OUT"
done

echo "[+] Listo. Resultado guardado en: $OUT"
