# persistencia-cifrada Specification

## Purpose

Encrypted SQLite persistence layer for Aprendo+. Provides AES-256 encrypted storage of student data, lesson content, interaction logs, and generated exercises with offline-first access.

## Requirements

### Requirement: Encrypted Database Initialization

The system MUST initialize an AES-256 encrypted SQLite database using `sqflite_sqlcipher` with a key derived from Android Keystore. On first launch, the schema (v1) SHALL be created via migration.

#### Scenario: Database creates on first launch

- GIVEN the app has never been opened on this device
- WHEN `DatabaseService.initialize()` is called
- THEN a new encrypted database file is created with AES-256
- AND all 4 tables exist in the v1 schema

#### Scenario: Database reopens with key

- GIVEN the encrypted database exists from a prior session
- WHEN the app relaunches
- THEN the database opens successfully with the stored key
- AND previously persisted data is readable

### Requirement: Schema Definition

The database SHALL have 4 tables:

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `student_profile` | Student anonymous data and diagnostic results | `id` (TEXT PK), `nivel` (INT), `theta` (REAL), `fecha_diagnostico` (TEXT) |
| `interaction_log` | Timestamped interaction records | `id` (INTEGER PK AUTO), `student_id` (FK), `tipo` (TEXT), `contenido` (TEXT), `timestamp` (TEXT) |
| `lesson_content` | Pre-authored lesson definitions | `id` (TEXT PK), `titulo` (TEXT), `tipo` (TEXT), `contenido_json` (TEXT) |
| `generated_exercises` | Gemma-generated reinforcement exercises | `id` (INTEGER PK AUTO), `lesson_id` (FK), `enunciado` (TEXT), `tipo` (TEXT), `respuesta_correcta` (TEXT) |

#### Scenario: Schema integrity at migration v1

- GIVEN the migration v1 executes
- WHEN `DatabaseService` introspection queries the schema
- THEN all 4 tables exist with the specified columns and types
- AND foreign key constraints are enforced

### Requirement: Content Precarga

On first launch after migration, the system MUST load 5 lesson definitions from `assets/data/lessons.json` and 50 diagnostic items from `assets/data/item_bank.json`, inserting them into `lesson_content` via a seed transaction.

#### Scenario: Content seeds on first launch

- GIVEN the database is fresh with no content
- WHEN the app completes initialization
- THEN 5 lesson rows exist in `lesson_content`
- AND 50 item rows exist ready for the diagnostic module

### Requirement: CRUD Operations

Repositories SHALL provide atomic Create, Read, Update, and Delete operations for all 4 tables. All ops MUST use parameterized queries. Write operations SHALL run within transactions.

#### Scenario: Student profile is persisted and read

- GIVEN a student completes the diagnostic
- WHEN the diagnostic result is saved to `student_profile`
- THEN a subsequent read by the same anonymous ID returns the saved `nivel` and `theta`
