# gemma-model-download Specification

## Purpose

Defines the HuggingFace OAuth PKCE model download pipeline for `.litertlm` models using flutter_gemma's ModelManager.

## Requirements

### Requirement: Model Download on First Launch

The system MUST detect model absence and initiate download via flutter_gemma's ModelManager with HuggingFace OAuth authentication.

#### Scenario: First launch triggers download

- GIVEN the app launches for the first time
- AND no compatible model exists in the MediaPipe cache directory
- WHEN model initialization flow starts
- THEN ModelManager begins downloading the model from the configured HuggingFace URL
- AND download progress is reported to the UI

#### Scenario: Model already installed — skip download

- GIVEN a valid model exists in cache
- WHEN model initialization is attempted
- THEN ModelManager confirms installation without re-downloading
- AND setModelPath() points to the existing file

### Requirement: Model Integrity Verification

The system SHALL verify downloaded model integrity via SHA256 checksum before accepting it for inference.

#### Scenario: Download completes with valid checksum

- GIVEN model download completes
- WHEN SHA256 hash matches the expected value
- THEN the model path is set and model loading proceeds

#### Scenario: Checksum mismatch triggers retry

- GIVEN download completes but SHA256 does not match
- WHEN verification runs
- THEN the corrupted file is deleted
- AND download is retried once
- AND on second failure the app falls back to emergency responses

### Requirement: Offline Resilience

The system MUST remain functional for core tutoring when the model cannot be downloaded due to lack of connectivity.

#### Scenario: No network — fallback active

- GIVEN the device has no internet connectivity
- WHEN model download is attempted
- THEN the download failure is handled gracefully
- AND FallbackDispatcher serves all inference requests from fallback_responses.json
- AND the app's tutoring features remain usable
