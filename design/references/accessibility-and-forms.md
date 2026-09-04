# Accessibility and forms

Read this reference for forms, custom controls, keyboard or assistive-technology
behavior, accessibility audits, or any flow where errors and recovery matter.
Accessibility is part of the interaction contract, not a final visual overlay.

## Apply the right standard

Identify the target platform, supported versions, and requested conformance level.
For web work, verify current WCAG and WAI-ARIA guidance. For native work, verify the
current platform accessibility APIs and conventions. Numeric thresholds and API
details can change; do not claim conformance from memory or from this reference
alone.

Automation can find some missing names, invalid roles, and contrast defects. It
cannot establish a sensible reading order, understandable language, usable focus
movement, or successful operation with assistive technology. Report automated,
manual, simulated, and user testing as separate evidence.

## Semantics and accessible names

Prefer native controls and document structure before adding ARIA or custom gesture
logic. Match role, name, value, state, and available actions to what the control
actually does.

- Use real headings, landmarks, lists, links, buttons, labels, and input types on
  the web. Do not repair a generic container with incomplete semantics when a native
  element already implements the behavior.
- Keep the accessible name stable and concise. Put instructions or consequences in
  descriptions and visible helper text rather than overloading the name.
- Hide an icon from the accessibility tree when adjacent text conveys the same
  meaning. Give meaningful standalone imagery a useful alternative. Give icon-only
  controls a name and expose selected, pressed, checked, or expanded state when
  applicable.
- Do not duplicate visible text through an extra live region or label. Test the
  announcement produced by the composed control.
- Keep source and reading order aligned with the intended visual order. Visual CSS
  reordering must not create a different keyboard or screen-reader sequence.

When implementing a composite widget such as a menu, combobox, grid, tab set, tree,
or dialog, follow the applicable platform pattern completely—including keyboard
commands, focus movement, states, and dismissal—or use a proven primitive.

## Keyboard, focus, pointer, and touch

Every action needs an operable path for the target input methods.

- Preserve a visible focus indicator with sufficient contrast against the actual
  surrounding colors. Do not remove it merely because pointer users dislike it.
- Keep tab order logical; avoid positive tab indices. Components may manage arrow-key
  movement internally when their established pattern requires it.
- On opening a modal or transient surface, move focus only when doing so helps the
  task. Trap focus only for genuinely modal content, provide a clear dismissal path,
  and return focus to a sensible location when it closes.
- Ensure sticky headers, banners, toolbars, virtual keyboards, and overlays do not
  obscure the focused element.
- Provide keyboard and single-pointer alternatives for author-defined dragging,
  multipoint gestures, hover-only actions, and precision movements.
- Keep visible control size separate from its hit area. Meet the applicable target
  standard: web, iOS points, and Android density-independent pixels are not
  interchangeable. Desktop controls may be compact while retaining clear pointer
  and keyboard operation.
- Do not intercept platform or assistive-technology shortcuts unless the product
  has an essential, documented reason and an alternative.

## Text, reflow, contrast, and media

- Let content reflow under browser zoom, system text scaling, localization, and
  user font settings without loss of information or controls.
- Distinguish normal text, large text, meaningful graphics, control boundaries, and
  focus indicators when applying contrast requirements; verify actual foreground
  and background values in every theme and state.
- Never encode state with color alone. Use labels, icons, shapes, patterns, or
  position as a redundant cue.
- Provide alternatives for meaningful non-text content. Decorative content should
  be ignored by assistive technology rather than described as noise.
- Give moving, blinking, auto-updating, or auto-playing content appropriate pause,
  stop, volume, and reduced-motion behavior. Avoid unexpected playback.

## Forms

Design the form as a conversation with preserved context, not a collection of input
boxes.

### Structure and entry

- Give every field a persistent visible label. Use placeholder text for examples,
  never as the only label or instruction.
- Group related fields and name the group. Explain format or consequences before
  entry when the user needs that information.
- Use semantic input types, input modes, autocomplete, and native pickers where they
  improve entry. Allow paste and password managers; do not create memory puzzles as
  authentication.
- Mark required and optional fields consistently in text, not only by color or an
  unexplained symbol.
- Make read-only, disabled, and unavailable states visually and semantically
  distinct. Prefer explaining why an action is unavailable over silently hiding it
  when that knowledge helps the user.

### Validation and recovery

- Validate at a moment that helps correction without punishing normal entry. Do not
  show an error for a partially typed value unless immediate validation is essential
  to the task.
- State what is wrong and how to fix it in plain language. Associate the message
  with its field and keep the user's value unless it is unsafe to do so.
- After a failed submission with several errors, provide a focusable summary whose
  entries move to the affected fields, while retaining inline errors. With one local
  error, focus or reveal it without disorienting the user.
- Do not rely on red borders, a toast, or an error at the top alone. Announce dynamic
  errors appropriately without producing duplicate or repeated speech.
- Preserve entered data across recoverable network errors, navigation, resizing,
  and authentication refresh. For long or high-cost entry, consider drafts or
  explicit save progress.

### Submission and completion

- Name actions by their result and use the same verb through confirmation and
  feedback. “Save changes” should not become “Submitted” after activation.
- Prevent accidental duplicate submission while showing progress. Do not disable a
  control without also making the busy state understandable.
- Put success or failure feedback near the initiating context. Long operations need
  progress or continuing status; background work needs a way to find its result.
- For destructive or bulk actions, prefer undo when recovery is safe. Otherwise use
  a confirmation that names the affected object and consequence; do not make every
  routine action pass through a dialog.
- Confirm before discarding unsaved work when loss would be surprising.

## Dynamic feedback

Use live announcements for meaningful asynchronous changes, not every visual
update. A status message should describe the completed context (“3 files uploaded”)
rather than an isolated number. Routine status must not steal focus. Urgent alerts
are rare and should not repeatedly interrupt the user.

Loading, empty, offline, permission, and failure states need useful next actions.
Skeletons should preserve a known content shape rather than imply data that may not
arrive. Empty states explain whether there is nothing yet, nothing matches, or the
user lacks access—those are different problems.

## Verification pass

Use the combinations relevant to the product:

- keyboard-only operation, including reverse traversal, escape routes, shortcuts,
  menus, and dialogs;
- browser zoom/reflow or largest supported system text size;
- a representative screen reader on each claimed platform;
- reduced motion, increased contrast, light/dark themes, and forced colors where
  supported;
- coarse pointer/touch and fine pointer, including target spacing and gesture
  alternatives;
- error injection, slow/offline states, expired permissions, and long or translated
  content.

Record concrete outcomes and residual gaps. A checklist pass without observing the
result is not evidence of usability or standards conformance.
