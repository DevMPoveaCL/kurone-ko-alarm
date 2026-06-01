# Alarm History Specification

## Purpose
Provide a visible record of past alarm outcomes with automatic 24-hour retention.

## Requirements

### Requirement: Status Tracking
The system MUST record an `AlarmEventStatus` (`fired`, `dismissed`, or `missed`) and a `statusChangedAt` timestamp when an alarm's outcome is known.

#### Scenario: Alarm Dismissed
- GIVEN a main alarm has fired
- WHEN the user dismisses it via the overlay or notification
- THEN the event status is updated to `dismissed`
- AND `statusChangedAt` is set to the dismissal time

#### Scenario: Alarm Fired Without Dismissal
- GIVEN a main alarm has triggered
- AND the user did not dismiss it before the next app open
- WHEN the app opens and synchronizes state
- THEN the event status is updated to `fired` or `missed` as supported by the native scheduler

### Requirement: History Display
The system MUST expose a history section that lists alarm events whose status is not `scheduled`, showing the contextual label and status.

#### Scenario: User Views History
- GIVEN there are past alarm events with status `fired` or `dismissed`
- WHEN the user navigates to the history section
- THEN each entry shows its contextual label and final status

### Requirement: 24-Hour Retention
The system MUST hard-delete history entries whose `statusChangedAt` is older than 24 hours when the app is opened.

#### Scenario: Old Entries Purged
- GIVEN the app is opened
- AND there are history entries older than 24 hours
- THEN those entries are permanently removed from persistence
- AND they no longer appear in the history section

### Requirement: Scheduled Exclusion
History queries MUST exclude events with status `scheduled`.

#### Scenario: Active Alarms Hidden
- GIVEN future or active scheduled alarms exist
- WHEN the history list is built
- THEN only events with a terminal status are included
