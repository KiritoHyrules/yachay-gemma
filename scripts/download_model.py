#!/usr/bin/env python3
"""
download_model.py — Descarga el modelo Gemma 4 E2B GGUF desde HuggingFace.

Modelo: google/gemma-4-E2B-it-qat-mobile-transformers
Formatos disponibles:
  - Q4_0 GGUF (~600-900 MB) — calidad estándar
  - IQ2_XXS GGUF (~2.0 GB) — optimizado para dispositivos de 3.8 GB (producido con scripts/quantize_model.py)
  - IQ2_M GGUF  (~2.6 GB) — balance calidad/RAM, default para ≥3.5 GB

Para dispositivos con <3.5 GB de RAM, usar IQ2_XXS (generado con quantize_model.py).
El modelo IQ2_M es la opción por defecto para la mayoría de dispositivos.

Uso:
    python download_model.py                # usa directorio default
    python download_model.py --output ./    # directorio personalizado

El archivo descargado se coloca en:
    android/app/src/main/assets/models/gemma-4-e2b-it-q4_0.gguf

Requiere: pip install huggingface_hub
"""

import argparse
import os
import sys
from pathlib import Path

# --- configuración ---
REPO_ID = "google/gemma-4-E2B-it-qat-mobile-transformers"
GGUF_PATTERN = "gemma-4-e2b"  # busca archivos GGUF que contengan este prefijo
DEFAULT_OUTPUT = Path(__file__).resolve().parent.parent / "android" / "app" / "src" / "main" / "assets" / "models"

# --- main ---

def main():
    parser = argparse.ArgumentParser(description="Descargar Gemma 4 E2B GGUF")
    parser.add_argument("--output", "-o", default=str(DEFAULT_OUTPUT),
                        help=f"Directorio de salida (default: {DEFAULT_OUTPUT})")
    parser.add_argument("--token", "-t", default=None,
                        help="HuggingFace token (necesario para modelos gated)")
    args = parser.parse_args()

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    # --- import ---
    try:
        from huggingface_hub import HfApi, hf_hub_download, list_repo_files
    except ImportError:
        print("ERROR: huggingface_hub no instalado.")
        print("  pip install huggingface_hub")
        sys.exit(1)

    # --- listar archivos del repo ---
    print(f"Buscando archivos GGUF en {REPO_ID}...")
    try:
        files = list_repo_files(REPO_ID, token=args.token)
    except Exception as e:
        print(f"ERROR al listar archivos: {e}")
        print("Si el modelo es gated, usá --token con tu HF token.")
        sys.exit(1)

    gguf_files = [f for f in files if f.endswith(".gguf") and GGUF_PATTERN in f.lower()]
    
    if not gguf_files:
        print("No se encontraron archivos GGUF. Buscando cualquier .gguf...")
        gguf_files = [f for f in files if f.endswith(".gguf")]
    
    if not gguf_files:
        print("ERROR: No se encontraron archivos GGUF en el repositorio.")
        print("Archivos disponibles:")
        for f in sorted(files)[:30]:
            print(f"  {f}")
        sys.exit(1)

    print(f"Archivos GGUF encontrados ({len(gguf_files)}):")
    for f in gguf_files:
        size_info = ""
        print(f"  [{size_info}] {f}")

    # --- elegir el más liviano (mobile-optimized) ---
    chosen = None
    for keyword in ["Q4_0", "q4_0", "IQ4", "mobile", "wNa8o8"]:
        matches = [f for f in gguf_files if keyword in f]
        if matches:
            chosen = matches[0]
            break
    if not chosen:
        chosen = gguf_files[0]  # fallback: el primero

    print(f"\nSeleccionado: {chosen}")
    local_name = "gemma-4-e2b-it-q4_0.gguf"
    local_path = output_dir / local_name

    # --- descargar ---
    print(f"Descargando {chosen} → {local_path} ...")
    print("(Esto puede tomar varios minutos — el archivo pesa ~600-900 MB)")
    
    try:
        downloaded = hf_hub_download(
            repo_id=REPO_ID,
            filename=chosen,
            local_dir=output_dir,
            local_dir_use_symlinks=False,
            token=args.token,
        )
        # renombrar al nombre canónico
        if Path(downloaded).name != local_name:
            target = output_dir / local_name
            if target.exists():
                target.unlink()
            Path(downloaded).rename(target)
            downloaded = str(target)
    except Exception as e:
        print(f"ERROR en descarga: {e}")
        sys.exit(1)

    # --- verificar ---
    size_mb = os.path.getsize(downloaded) / (1024 * 1024)
    print(f"\n✓ Modelo descargado: {downloaded}")
    print(f"  Tamaño: {size_mb:.0f} MB")

    # --- siguiente paso ---
    print(f"""
Siguiente paso:
  Asegurate de que el modelo esté en assets/models/ y que build.gradle
  no comprima el archivo (agregar extensión .gguf a aaptOptions.noCompress).

  Luego:
    flutter build apk --debug
""")

if __name__ == "__main__":
    main()
