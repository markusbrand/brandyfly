## Purpose

Enables users to personalize their flight screens by dragging, dropping, resizing, and configuring widgets individually.

## ADDED Requirements

### Requirement: Drag and Drop Widgets
The system SHALL allow users in edit mode to drag and drop widgets to new positions on the screen layout grid.

#### Scenario: Successful drag and drop
- **WHEN** user is in edit mode and drags a widget to an empty grid location
- **THEN** the widget is placed at the new location and its settings are saved.

### Requirement: Resize Widgets
The system SHALL allow users in edit mode to resize widgets (change width and height).

#### Scenario: Successful widget resize
- **WHEN** user is in edit mode and taps/drags a widget's resize handle
- **THEN** the widget's dimensions are updated and its settings are saved.

### Requirement: Individual Widget Configuration
The system SHALL allow users in edit mode to tap a widget to configure its visual style and settings independently from other widgets of the same type.

#### Scenario: Successful individual configuration
- **WHEN** user taps a widget in edit mode and changes a visual style setting
- **THEN** the new setting applies only to that specific widget instance.
