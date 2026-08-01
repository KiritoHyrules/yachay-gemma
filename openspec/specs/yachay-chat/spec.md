# yachay-chat Specification

> NEW capability: single-screen chat-first UI with Yachay Socratic tutor persona

## Purpose

Replace the three-screen diagnostic→ruta→lección tunnel with a conversational interface where Yachay (Gemma) orchestrates the entire learning experience through natural chat (N-01, N-03).

## Requirements

### Requirement: Chat-First Single Screen

The system SHALL present ONE screen where the student converses with Yachay. User messages MUST render right-aligned in blue bubbles, Yachay messages MUST render left-aligned in white bubbles with avatar. There SHALL be no navigation away from this screen for learning content — all instruction, exercises, and diagnostics occur inline in the chat.

#### Scenario: Student sends first message

- GIVEN a new student opens the app for the first time
- WHEN the chat screen loads
- THEN Yachay MUST initiate conversation with a Peruvian-Spanish greeting introducing itself
- AND the prompt bar MUST be visible and enabled

#### Scenario: Message bubble rendering

- GIVEN the chat contains messages from both the student and Yachay
- WHEN the message list renders
- THEN student messages MUST appear right-aligned with blue background
- AND Yachay messages MUST appear left-aligned with white background and Yachay avatar
- AND the list MUST auto-scroll to the latest message

### Requirement: Prompt Bar

The system SHALL display a fixed prompt bar at screen bottom with: text input field, send button, and microphone button (placeholder, disabled). The prompt bar SHALL NOT scroll with the message list.

#### Scenario: Send text message

- GIVEN the student types "hola Yachay" in the prompt bar
- WHEN the send button is tapped
- THEN the message MUST appear in the chat
- AND `GemmaService.procesarMensaje("hola Yachay")` MUST be invoked
- AND the input field MUST be cleared

### Requirement: Thinking Indicator

During inference, the system SHALL display "Yachay está pensando..." with an animated indicator in place of the next Yachay message bubble.

#### Scenario: Model inference in progress

- GIVEN the student has sent a message that requires model inference
- WHEN `GemmaService.procesarMensaje()` is executing
- THEN a thinking indicator MUST appear in the message list showing "Yachay está pensando..."
- AND the prompt bar MUST be disabled

#### Scenario: Inference completes

- GIVEN the thinking indicator is displayed
- WHEN inference completes and Yachay's response is available
- THEN the thinking indicator MUST be replaced by Yachay's message bubble
- AND the prompt bar MUST re-enable

### Requirement: Context Chips

Above the prompt bar, the system SHALL display 3-4 quick-action chips: "Explicar", "Practicar", "Mi progreso", "Cambiar tema". Tapping a chip SHALL send the chip's text as a user message.

#### Scenario: Student taps context chip

- GIVEN context chips are visible above the prompt bar
- WHEN the student taps "Practicar"
- THEN the text "Quiero practicar" MUST be sent as a user message
- AND the dispatch loop MUST process it

### Requirement: Bottom Navigation

The system SHALL render a bottom navigation bar with three tabs: Chat, Camino, Perfil. Tapping Camino or Perfil SHALL navigate to those screens while preserving chat state.

#### Scenario: Navigate to Camino

- GIVEN the student is on the Chat tab with an active conversation
- WHEN the student taps the Camino tab
- THEN the progress map screen MUST display
- AND returning to Chat MUST restore the conversation intact
