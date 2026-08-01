# gemma-mobile-quantize Specification

> NEW: Developer quantization pipeline for BF16 → IQ2_XXS GGUF production

## Purpose

Provide a reproducible developer script to produce IQ2_XXS GGUF from the BF16 base model using vendored llama-quantize, with integrity verification via SHA256 (SR-B07).

## Requirements

### Requirement: Quantization Script

The project SHALL provide `scripts/quantize_model.py` that wraps llama-quantize from the vendored llama.cpp build. The script MUST accept a BF16 GGUF input path and produce an IQ2_XXS GGUF output file.

#### Scenario: Successful quantization run

- GIVEN `gemma-4-E2B-it-BF16.gguf` (~9.31 GB) exists at the input path
- WHEN `python scripts/quantize_model.py --input gemma-4-E2B-it-BF16.gguf --output gemma-4-E2B-it-IQ2_XXS.gguf --quant IQ2_XXS` is executed
- THEN llama-quantize MUST produce a valid IQ2_XXS GGUF file
- AND the output SHALL be ~2.0 GB
- AND the script MUST exit with code 0

#### Scenario: Missing input file fails gracefully

- GIVEN the BF16 input file does not exist at the specified path
- WHEN the quantization script runs
- THEN it MUST print a clear error: "BF16 model not found at {path}"
- AND MUST exit with non-zero code
- AND SHALL NOT create a corrupt output file

### Requirement: Integrity Verification

The quantization script SHALL compute and output a SHA256 hash of the produced IQ2_XXS GGUF file for distribution integrity verification.

#### Scenario: SHA256 hash produced

- GIVEN quantization completed successfully
- WHEN the script finalizes
- THEN it MUST compute SHA256 of the output GGUF
- AND print the hash to stdout: `sha256: <hex>`
- AND the hash SHALL be recorded for Hugging Face LFS upload verification

### Requirement: Quantization Tool Dependency

The script SHALL depend on `llama-quantize` from the vendored llama.cpp build (`android/app/src/main/cpp/llama.cpp/build/bin/`). The script MUST verify the binary exists before execution.

#### Scenario: llama-quantize binary not found

- GIVEN the llama.cpp build has not been compiled
- WHEN the quantization script runs
- THEN it MUST check for `llama-quantize` binary existence
- AND if absent, print: "llama-quantize not found. Build llama.cpp first."
- AND exit with non-zero code
