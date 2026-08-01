#!/usr/bin/env python3
"""
quantize_model.py — Quantize a BF16 GGUF model to IQ2_XXS for low-RAM devices.

Wraps the vendored llama-quantize binary to produce a mobile-optimized
IQ2_XXS GGUF (~2.0 GB) from the BF16 base model (~9.31 GB), verified
with SHA256 hashing for distribution integrity.

Usage:
    python scripts/quantize_model.py --input gemma-4-E2B-it-BF16.gguf --output gemma-4-E2B-it-IQ2_XXS.gguf
    python scripts/quantize_model.py --input model.gguf --output model.gguf --quant Q4_0

Requirements:
    - llama-quantize built from vendored llama.cpp (android/app/src/main/cpp/llama.cpp/build/bin/)
    - Python 3.9+
"""

import argparse
import hashlib
import os
import shutil
import subprocess
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Minimum expected size for a BF16 GGUF (~9.31 GB for Gemma 4 E2B).
MIN_INPUT_SIZE_GB = 8

# Default quantization type
DEFAULT_QUANT = "IQ2_XXS"

# Vendored llama.cpp build directory (relative to project root).
VENDORED_LLAMA_BUILD = (
    Path(__file__).resolve().parent.parent
    / "android" / "app" / "src" / "main" / "cpp" / "llama.cpp" / "build"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _find_llama_quantize() -> Path:
    """Locate the llama-quantize binary.

    Checks the vendored build directory first, then falls back to PATH.
    Returns the absolute path on success, exits on failure.
    """
    # Try vendored build dir.
    vendored_bin = VENDORED_LLAMA_BUILD / "bin" / "llama-quantize"
    if vendored_bin.exists():
        return vendored_bin.resolve()

    # Try vendored build dir (Windows .exe variant).
    vendored_exe = VENDORED_LLAMA_BUILD / "bin" / "llama-quantize.exe"
    if vendored_exe.exists():
        return vendored_exe.resolve()

    # Try PATH.
    which = shutil.which("llama-quantize")
    if which:
        return Path(which)

    print(
        "ERROR: llama-quantize not found.\n"
        f"  Checked: {vendored_bin}\n"
        "  Build llama.cpp first:\n"
        "    cd android/app/src/main/cpp/llama.cpp\n"
        "    mkdir -p build && cd build\n"
        "    cmake .. -DCMAKE_BUILD_TYPE=Release\n"
        "    cmake --build . --target llama-quantize -j$(nproc)"
    )
    sys.exit(1)


def _sha256(path: Path) -> str:
    """Compute SHA256 hex digest of a file."""
    sha = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(8192)
            if not chunk:
                break
            sha.update(chunk)
    return sha.hexdigest()


def _validate_input(input_path: Path) -> None:
    """Validate that the input BF16 GGUF exists and meets the size heuristic."""
    if not input_path.exists():
        print(f"ERROR: BF16 model not found at {input_path}")
        sys.exit(1)

    size_gb = input_path.stat().st_size / (1024**3)
    if size_gb < MIN_INPUT_SIZE_GB:
        print(
            f"WARNING: Input file is {size_gb:.1f} GB, below the expected "
            f"{MIN_INPUT_SIZE_GB} GB minimum for BF16. Proceeding anyway, but "
            f"verify this is a BF16 GGUF (not an already-quantized file)."
        )
    else:
        print(f"Input file: {input_path} ({size_gb:.1f} GB)")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Quantize BF16 GGUF → IQ2_XXS for mobile inference"
    )
    parser.add_argument(
        "--input", "-i",
        required=True,
        help="Path to BF16 GGUF model file",
    )
    parser.add_argument(
        "--output", "-o",
        required=True,
        help="Path for the output IQ2_XXS GGUF file",
    )
    parser.add_argument(
        "--quant", "-q",
        default=DEFAULT_QUANT,
        help=f"Quantization type (default: {DEFAULT_QUANT})",
    )
    args = parser.parse_args()

    input_path = Path(args.input).resolve()
    output_path = Path(args.output).resolve()
    quant_type = args.quant

    # --- Validate input ---
    _validate_input(input_path)

    # --- Locate llama-quantize ---
    llama_quantize = _find_llama_quantize()
    print(f"llama-quantize: {llama_quantize}")

    # --- Execute quantization ---
    cmd = [
        str(llama_quantize),
        str(input_path),
        str(output_path),
        quant_type,
    ]
    print(f"Running: {' '.join(cmd)}")
    print("This may take several minutes for a ~9 GB input file...")

    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=3600,  # 1 hour timeout
        )
        # Print llama-quantize output so the user can monitor progress.
        if result.stdout:
            print(result.stdout)

        if result.returncode != 0:
            print(f"ERROR: llama-quantize exited with code {result.returncode}")
            # Clean up partial output file.
            if output_path.exists():
                output_path.unlink()
            sys.exit(result.returncode)
    except subprocess.TimeoutExpired:
        print("ERROR: Quantization timed out (1 hour limit).")
        if output_path.exists():
            output_path.unlink()
        sys.exit(1)
    except FileNotFoundError:
        print(f"ERROR: Could not execute {llama_quantize}")
        sys.exit(1)

    # --- Verify output ---
    if not output_path.exists():
        print(f"ERROR: Output file was not created at {output_path}")
        sys.exit(1)

    output_size_gb = output_path.stat().st_size / (1024**3)
    print(f"Output file: {output_path} ({output_size_gb:.2f} GB)")

    # --- SHA256 ---
    print("Computing SHA256 hash...")
    sha = _sha256(output_path)
    print(f"sha256: {sha}")

    print("\nQuantization complete. Copy the IQ2_XXS GGUF to the device:")
    print(f"  adb push {output_path} /sdcard/")
    print("Or place it in the app's internal files directory.")
    sys.exit(0)


if __name__ == "__main__":
    main()
