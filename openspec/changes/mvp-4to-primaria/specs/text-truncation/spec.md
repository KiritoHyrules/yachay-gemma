# text-truncation Specification

## Purpose

Sentence-aware text truncation using ONLY native `String` methods. Zero `RegExp` — validated explicitly (N-03).

## Requirements

### Requirement: Sentence-Aware Truncation

The system MUST provide `String truncateAtSentence(String text)` that truncates at the nearest sentence boundary using native `String.lastIndexOf()`. Priority: `'.'` > `'!'` > `'?'` > `';'` > `','`. The function MUST NOT use `RegExp` in any form.

#### Scenario: Multi-sentence truncates at last period

- GIVEN text: "Aprendo+ usa IA. Explica temas difíciles. Ayuda a estudiantes."
- WHEN `truncateAtSentence(text)` is called
- THEN result MUST be "Aprendo+ usa IA. Explica temas difíciles."
- AND `RegExp` MUST NOT appear in the implementation

#### Scenario: No punctuation — returns full text

- GIVEN text: "Esto es un texto sin puntuación alguna"
- WHEN `truncateAtSentence(text)` is called
- THEN result MUST equal the original text

#### Scenario: Empty string

- GIVEN text: ""
- WHEN `truncateAtSentence(text)` is called
- THEN result MUST be ""

#### Scenario: Single sentence with period

- GIVEN text: "Hola mundo."
- WHEN `truncateAtSentence(text)` is called
- THEN result MUST be "Hola mundo."

#### Scenario: Exclamation priority over question

- GIVEN text: "¿Qué es esto? ¡Qué fácil! Vamos."
- WHEN `truncateAtSentence(text)` is called
- THEN result MUST be "¿Qué es esto? ¡Qué fácil!"

#### Scenario: Unicode and emoji preserved

- GIVEN text: "¡Qué fácil! 😊 Vamos a aprender más."
- WHEN `truncateAtSentence(text)` is called
- THEN result MUST preserve "¡Qué fácil! 😊"
- AND unicode/emoji characters MUST remain intact

#### Scenario: Semicolon fallback

- GIVEN text: "Primero; segundo; tercero sin puntuación"
- WHEN `truncateAtSentence(text)` is called
- THEN result MUST be "Primero; segundo;"
