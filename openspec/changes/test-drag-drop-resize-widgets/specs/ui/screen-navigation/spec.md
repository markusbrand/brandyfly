## Purpose

Enables users to navigate between multiple configured flight screens by swiping horizontally.

## ADDED Requirements

### Requirement: Horizontal Swipe Navigation
The system SHALL allow users to swipe left or right to navigate between available flight screens.

#### Scenario: Successful horizontal swipe
- **WHEN** the user is not in edit mode and swipes left or right on the flight screen
- **THEN** the system navigates to the adjacent flight screen configuration, skipping the automatically triggered thermaling screen.
