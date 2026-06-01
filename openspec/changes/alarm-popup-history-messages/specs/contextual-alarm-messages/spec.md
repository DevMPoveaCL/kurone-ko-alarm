# Contextual Alarm Messages Specification

## Purpose
Replace generic alarm labels with contextual, purpose-driven text in neutral Spanish across all user-facing surfaces.

## Requirements

### Requirement: Purpose-Driven Labels
The system MUST derive alarm labels from `AlarmEventPurpose` and, for break-related purposes, include the break's ordinal position.

#### Scenario: Break Alarm
- GIVEN an alarm has `purpose = breakStart`
- AND it is the first break in the plan
- AND the alarm type is `main`
- THEN the label is "Alarma 1° Break Inicio"

#### Scenario: Break Pre-Warning
- GIVEN an alarm has `purpose = breakStart`
- AND it is the first break in the plan
- AND the alarm type is `preWarning`
- THEN the label is "Preaviso de 1° Break Inicio"

#### Scenario: Non-Break Alarm
- GIVEN an alarm has `purpose = lunchStart`
- AND the alarm type is `main`
- THEN the label is "Alarma Inicio de Almuerzo"

### Requirement: Surface Synchronization
The same contextual label for an alarm MUST appear on the Flutter timeline, Android notification title/body, and `AlarmRingingActivity` fallback strings.

#### Scenario: Label Consistency
- GIVEN a scheduled alarm with a computed contextual label
- WHEN it is displayed in the timeline, posted as a notification, and shown in the full-screen overlay
- THEN all three surfaces show identical text for that alarm

### Requirement: Neutral Spanish
All labels MUST use neutral Spanish without Rioplatense slang or voseo.

#### Scenario: Language Check
- GIVEN any generated alarm label
- THEN the text uses standard Spanish forms (e.g., "Inicio", "Descanso", "Almuerzo") and excludes regionalisms
