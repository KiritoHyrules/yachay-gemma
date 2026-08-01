# dynamic-chips Specification

## Purpose

Context-aware chat chips replacing hardcoded options with curriculum-driven quick actions loaded from `Curricula4toPrimaria.temas` (N-03).

## Requirements

### Requirement: Dynamic Chip Loading from Curriculum

The system MUST replace hardcoded chips in `ChatScreen`'s `_ContextChipRow` with chips from `Curricula4toPrimaria.temas`, filtered by current area/topic.

#### Scenario: Chips reflect current area

- GIVEN the current conversation is in area "Matemática"
- WHEN the chat input renders
- THEN 3-4 chips MUST display from Matemática topics
- AND each chip text MUST come from `TemaPrimaria.chips`

#### Scenario: Chip tap sends pre-formatted message

- GIVEN a chip labeled "Explicame las fracciones" is displayed
- WHEN the student taps that chip
- THEN a message "Explicame las fracciones" MUST be sent to chat
- AND the message MUST appear as a student bubble

#### Scenario: Chips update on topic change

- GIVEN current topic changes from "com-01" to "mat-02"
- WHEN the next chat turn renders
- THEN chips MUST reload from the new topic's `chips`
- AND stale chips from the previous topic MUST NOT appear

#### Scenario: Chips handle overflow gracefully

- GIVEN a topic has chips that exceed screen width
- WHEN the chip row renders
- THEN chips MUST wrap or scroll horizontally
- AND no chip text SHALL be truncated mid-word

#### Scenario: No chips available

- GIVEN the current topic has an empty `chips` list
- WHEN the chat input renders
- THEN the chip row MUST be hidden or display "Pregúntame cualquier cosa"
