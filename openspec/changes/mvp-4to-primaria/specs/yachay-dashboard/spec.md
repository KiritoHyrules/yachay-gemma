# Delta for yachay-dashboard

## REMOVED Requirements

### Requirement: Student List with Mastery Overview

(Reason: Teacher Dashboard frozen for Phase 2. Removes active routing and imports.)
(Migration: Comment out or remove `teacher_dashboard.dart` with "Fase 2" marker. Remove dashboard routes from navigation. No student-facing impact.)

### Requirement: Per-Student Topic Breakdown

(Reason: Frozen with dashboard — Phase 2 feature.)
(Migration: None required. Detail screen removed with parent dashboard.)

### Requirement: "Recomendación de Yachay"

(Reason: Frozen with dashboard — Phase 2 feature.)
(Migration: None required. `yachay_recomendacion` field preserved in DB for future use.)

### Requirement: Offline-Only Operation

(Reason: Frozen with dashboard — Phase 2 feature.)
(Migration: None required. All other modules remain offline-only (N-04, N-08).)
