---
name: design
description: Design, implement, review, or refine product interfaces for desktop, web, iOS, and Android. Use for UI/UX direction, accessibility, adaptive layout, interaction, design systems, or platform-native behavior; not standalone graphics.
license: MIT; see LICENSE and THIRD_PARTY_NOTICES.md
metadata:
  version: "0.1.0"
---

# Design

Create coherent product interfaces whose visual language, interaction model, and
platform behavior follow the actual brief. Preserve the user's product choices,
existing design system, and implementation constraints unless changing them is in
scope.

## Establish the design problem

Before choosing a style or writing UI code, determine from the request and project:

- the product, audience, primary task, and real content or data;
- the target platforms, window and viewport range, and input modes;
- the information hierarchy, navigation depth, important states, and constraints;
- whether the task is creation, a focused change, or a review.

Inspect the existing interface and tokens when they exist. Use realistic content;
do not let placeholder copy determine the layout. If important context is missing,
make the smallest reversible assumption and state it. Do not turn a past example or
personal taste into a universal rule.

Route the work by mode:

- For creation or material redesign, establish a direction and system, implement a
  complete slice, and run the full applicable review.
- For a focused change, preserve the surrounding system and behavior, make the
  smallest coherent change, match neighboring states and accessibility, and review
  only affected paths. Do not redesign unrelated areas.
- For review, do not edit unless requested. Follow the rendered review sequence in
  [Interaction and review](references/interaction-and-review.md), rank findings by
  impact, cite observed evidence, and distinguish unverified concerns.

## Form an intentional direction

For creation or material redesign, draft the direction compactly before substantial
implementation: hierarchy and composition, typography, color roles, density and
spacing, surfaces, icon language, and interaction model. Test those choices against
the brief, revise anything generic or disconnected from the product, and state what
changed before building. Ground choices in the subject matter and usage context,
not in a fashionable named style. Spend visual emphasis on what matters most and
remove decoration that does not clarify structure, state, or identity.

When the user requests multiple concepts, make them genuinely different. Each
concept needs its own coherent combination of composition, visual language,
density, typography, navigation, surfaces, and interaction model. Vary several
structural axes and explain the tradeoff; a recolor, font swap, or altered radius is
not a new concept.

For a new direction or a visual-system change, read
[Visual and system foundations](references/visual-systems.md). Do not default to a
marketing-page structure: tools, settings, data products, and native applications
should be organized around their working tasks.

## Make the system fit the product

Turn repeated decisions into a small semantic system: roles for type, color,
spacing, shape, elevation, and motion; reusable component anatomy; and complete
interaction states. Reuse the project's established primitives when they are sound.
Add tokens or components only when repetition or variation justifies them—do not
invent a speculative library for one screen.

Keep structure and semantics native to the implementation. Prefer platform or web
primitives before recreating behavior. Component APIs should express purpose and
state, allow composition where needed, and keep behavior correct without depending
on a particular visual treatment.

## Design all behavior, not only the resting screen

Account for loading, empty, error, success, disabled, selected, focused, pressed,
and permission-limited states where relevant. Give every action clear feedback and
every failure a recovery path. Preserve user input and context across errors,
navigation, resizing, and interruption whenever the product permits it.

- For forms, custom controls, keyboard behavior, or accessibility review, read
  [Accessibility and forms](references/accessibility-and-forms.md).
- For responsive web, desktop, iOS, Android, or cross-platform work, read the
  applicable sections of
  [Adaptive and platform behavior](references/adaptive-and-platforms.md).
- For gestures, motion, asynchronous feedback, or a final UI pass, read
  [Interaction and review](references/interaction-and-review.md).

Platform guidance is conditional. iOS, Android, web, desktop, and React Native
conventions inform their own targets; none is a global template. When a current
platform rule or accessibility criterion matters, verify it against the applicable
official guidance and the project's supported versions.

## Implement and inspect

Build the smallest complete slice that demonstrates the intended hierarchy and
behavior. Keep layout adaptive to content, text growth, localization, window size,
input method, safe areas, and system preferences. Motion should explain cause,
continuity, or feedback and remain interruptible; it must not carry meaning alone.

Inspect the rendered result whenever the environment permits it. Compare relevant
sizes, themes, content extremes, and interaction states rather than judging source
code alone. Test keyboard and focus behavior, touch or pointer behavior, text
scaling, zoom, and reduced motion as applicable. Fix task flow and hierarchy before
surface polish.

For created or materially reshaped UI, complete the review checklist in
[Interaction and review](references/interaction-and-review.md) before delivery.
Report what was actually inspected or tested; do not present static inspection or
automated checks as complete usability or accessibility validation.

Licensing note: this file contains substantially modified material derived from
Anthropic's `frontend-design` skill. See
[Third-Party Notices](THIRD_PARTY_NOTICES.md).
