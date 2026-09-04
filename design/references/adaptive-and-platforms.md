# Adaptive and platform behavior

Read the shared section for any interface that changes with window, viewport,
content, or input. Then read only the sections for the platforms in scope. Platform
conventions are defaults to evaluate, not rules to transplant elsewhere.

## Adapt from constraints, not device labels

Design for available space, content pressure, input precision, posture, and feature
capability. A “desktop” window can be narrow; a tablet can have a keyboard and
pointer; a mobile app can run in split view.

- Set layout changes where content or controls stop working, not at arbitrary device
  names. Use component/container conditions when a component's own space matters and
  viewport conditions when the whole shell changes.
- Prefer reflow, reprioritization, and disclosure over uniform shrinking. Keep the
  primary task and current context available as secondary regions fold, move, or
  become transient.
- Test the smallest useful width, wide windows, short viewports, landscape, text
  growth, localization, zoom, virtual keyboards, safe areas, and resizable panes.
- Prevent accidental horizontal overflow while preserving intentional two-axis
  surfaces such as canvases, timelines, and data grids. Give those surfaces their
  own navigation and orientation cues.
- Reserve space around fixed or sticky UI so content and focus are not hidden.
- Preserve selection, scroll, filters, drafts, and navigation state through layout
  changes whenever possible.
- Detect input capabilities rather than equating width with touch or hover. Hover is
  supplemental; essential actions must remain visible or otherwise discoverable.

Navigation should follow information architecture and task frequency. Changing a
rail into a bar or an inspector into a sheet can be appropriate, but do not expose
the same hierarchy simultaneously through several competing patterns. Keep Back and
close semantics distinct: Back moves through navigation or history; close dismisses
a transient surface.

## Desktop applications

A desktop product should feel like a windowed tool, not a stretched marketing site.
Use the host operating system and chosen desktop framework as the final authority.

### Window and chrome

- If using custom title bars, define drag regions only on inert chrome. Exclude
  buttons, tabs, fields, menus, scrollbars, selectable content, and resize affordances
  from dragging. Preserve platform behavior such as title-bar double-click when the
  framework supports it.
- Support resizing, minimum usable dimensions, maximized/full-screen modes, display
  scaling, and multiple monitors as relevant. Avoid a layout that works only at the
  design screenshot's window size.
- Use system dialogs, menus, notifications, and file affordances when their familiar
  behavior is part of the task. Custom treatment must preserve keyboard access,
  modality, focus return, and platform settings.

### Input and selection

- Make text selectable where users reasonably copy, inspect, or edit it. Disable
  selection on buttons, draggable chrome, decorative labels, and other control
  surfaces where accidental highlighting feels broken; do not apply a blanket
  `user-select: none` to content.
- Provide complete keyboard traversal and visible focus. Important or repeated
  commands should have discoverable shortcuts and menu equivalents; respect standard
  edit, window, and accessibility shortcuts.
- Use default/cancel behavior, arrow-key navigation, space/enter activation, escape,
  and focus restoration according to the platform and control type.
- Right-click or context menus may expose contextual actions, but frequent or
  essential actions need a visible or keyboard-discoverable route.
- Double-click can accelerate a conventional action such as opening an item, but it
  must not be the only path. Distinguish selection from activation and preserve the
  user's multi-select model.
- Drag-and-drop needs clear pickup, valid-target, rejected-target, completion, and
  cancellation feedback plus a non-drag alternative. Avoid conflicts with text
  selection, scrolling, window dragging, and system gestures.
- Use pointer shapes that match the actual affordance. Do not put a hand cursor on
  every desktop control if the platform uses it specifically for links.

### Density and structure

Desktop work surfaces may use compact rows, toolbars, split views, tables, trees,
inspectors, menus, and context actions. Maintain usable targets and breathing room,
but do not inflate every element to mobile proportions. Avoid a repetitive grid of
large rounded cards, oversized headings, and vast gutters when the task needs
scannability, comparison, or sustained work. Generic Bootstrap-style website chrome
is not a substitute for a native desktop information and interaction model.

Keep selection, active focus, hover, and keyboard focus visually distinguishable.
Back should restore the prior view and local state where the platform or product
offers navigation; it should not silently reset the workspace.

## Web

- Preserve browser navigation, URL addressability, deep links, reload, zoom, text
  selection, and expected shortcuts. Do not emulate a native shell by breaking web
  fundamentals.
- Start with semantic HTML and progressive enhancement. Use responsive images and
  reserve their aspect ratio; defer non-critical work without hiding core content
  behind client-side effects.
- Test keyboard and pointer behavior independently. Do not require hover to reveal
  the only route to an action, and do not treat every screen as coarse-pointer touch.
- Use page-level breakpoints for shell changes and container queries for reusable
  components when supported by the project's browser policy. Provide a sound base
  behavior when newer capabilities are unavailable.
- Keep meaningful route changes reflected in history and move focus appropriately
  for assistive-technology users without disrupting ordinary browser focus.

## iOS and iPadOS

- Prefer native navigation, controls, typography roles, semantic colors, and system
  behaviors when they fit the product. Custom visuals may establish brand, but must
  preserve Dynamic Type, VoiceOver, safe areas, contrast, and familiar interaction.
- Keep primary touch targets at least 44 by 44 points unless current Apple guidance
  or a documented exception applies; a smaller glyph can have a larger hit area.
- Respect swipe-back, system gestures, sheets, tab and hierarchical navigation, and
  the distinction between dismissing and navigating back. Do not make a custom
  gesture compete at screen edges.
- Design iPad layouts for resizing, multitasking, keyboard, pointer, sidebar or
  multi-column opportunities, and readable content widths—not merely a scaled phone
  canvas.
- SF Symbols and system materials are useful platform resources, not mandatory brand
  language and not rules for Android, web, or desktop.

## Android

- Follow the project's supported Material and Android conventions for navigation,
  controls, system bars, accessibility, and state restoration. A custom design can
  change appearance without discarding expected Back or lifecycle behavior.
- Keep touch targets at least 48 by 48 dp unless current Android guidance or a
  documented exception applies; keep visible size and hit area separate.
- Support system and predictive Back as applicable. Back should move through the
  user's real task history, dismiss transient layers in the correct order, and avoid
  unexpected jumps to the start destination.
- Adapt across window size classes, landscape, tablets, foldables, keyboard/pointer
  input, cutouts, and system insets. Do not assume one full-screen phone window.
- Dynamic color, Material components, and Jetpack Compose are target-specific tools,
  not requirements for all Android products and never global rules for other
  platforms.

## React Native and other cross-platform shells

Share product semantics, tokens, and domain behavior while preserving platform
differences that users notice: Back, navigation transitions, safe areas, controls,
text metrics, accessibility APIs, selection, gestures, menus, and keyboard behavior.
Do not choose the lowest common denominator merely to maximize shared code.

- Keep platform forks narrow and intentional. Separate behavior when one abstraction
  would make either platform feel wrong or inaccessible.
- Use native semantic controls and accessibility props; test the resulting platform
  accessibility tree rather than assuming a shared component maps correctly.
- Run high-frequency gestures and motion through the framework's supported
  performant path, but keep correctness independent of animation completion.
- Use virtualized collections for long data and verify dynamic row height, text
  scaling, keyboard avoidance, restoration, and safe-area behavior on real targets.

## Platform verification

Check current official guidance and the actual framework version before encoding a
platform-specific API, size, or navigation behavior. Test on representative real
targets when haptics, system gestures, accessibility services, window chrome, or
performance are material; simulators and browser emulation are partial evidence.
