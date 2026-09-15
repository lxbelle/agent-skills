# Interaction and review

Licensing note: this file contains substantially modified material derived from
Anthropic's `frontend-design` skill. See
[Third-Party Notices](../THIRD_PARTY_NOTICES.md).

Read this reference for motion, gestures, asynchronous behavior, or the final review
of created or materially reshaped UI.

## Model the states first

For every interactive element and data region, identify the states users can
actually encounter. Depending on the control, this can include default, hover,
pressed, keyboard focus, selected, expanded, disabled, read-only, busy, loading,
empty, partial, stale, offline, denied, error, and success.

- Make visually similar states semantically compatible. Focus is not selection;
  disabled is not read-only; loading is not an empty result.
- Keep state changes from shifting surrounding layout unless movement is part of the
  intended transition.
- Preserve correctness if feedback is skipped, interrupted, or reduced. Never rely
  on an animation-end callback as the only way to reach the final application state.
- Keep the latest user intent authoritative. Rapid toggles, repeated filtering, or
  interrupted navigation must cancel or supersede stale transitions and requests.

## Feedback and latency

Feedback should answer: what received the action, what changed, whether work is
continuing, and what the user can do next.

- Show pressed or active feedback immediately at the point of interaction.
- For short indeterminate waits, use a restrained busy state. For longer work, show
  continuing progress or status; use determinate progress when the measure is real.
- Use a skeleton only when the expected content structure is known and stable.
  Reserve its layout and avoid decorative shimmer when reduced motion is requested.
- Prevent duplicate destructive or transactional actions while busy, but keep
  navigation or cancellation available when safe.
- Put errors near their source, preserve context, and offer a specific recovery
  action. A toast alone is insufficient for an error that the user must fix.
- Confirm completion in the same vocabulary as the action. Background operations
  need a durable place where their status and result can be found.

## Motion

Use motion to provide feedback, show continuity, explain hierarchy, or direct
attention to a meaningful change. Decoration alone is rarely enough reason.

- Choose duration and easing from distance, mass, complexity, platform, and urgency.
  Reuse a small rhythm, but do not force one duration onto every transition.
- Make entrance, exit, and reversal feel causally connected. Exits often benefit from
  being quicker, but responsiveness matters more than a fixed ratio.
- Keep motion interruptible and allow input throughout unless the underlying state
  is genuinely unavailable.
- Prefer rendering paths that avoid unnecessary layout and main-thread work. Measure
  on the target before claiming smoothness; not every layout animation is inherently
  wrong, and not every transform is inherently cheap.
- Respect system reduced-motion settings. Replace large spatial movement, parallax,
  flashing, or repeated choreography with a stable transition while retaining state
  and completion feedback.
- Avoid generic page-load cascades and hover movement on every surface. One coherent
  transition serving the task is stronger than many unrelated effects.

## Gestures and direct manipulation

- Track the pointer or touch continuously during direct manipulation and clearly
  show pickup, valid destinations, constraints, rejected destinations, and the final
  result.
- Use a movement threshold so clicks, scrolling, text selection, and drag are not
  confused. Support cancellation and safe rollback.
- Keep one dominant gesture per region and avoid conflicts with Back, scrolling,
  window dragging, edge gestures, zoom, and assistive technology.
- Make critical swipe, pinch, drag, long-press, hover, context-menu, and double-click
  actions available through a visible, keyboard, or single-pointer alternative.
- For reorder or move operations, announce position and result to assistive
  technology and provide an undo path when practical.

## Interface language

Words are part of navigation and feedback.

- Use the user's vocabulary, plain verbs, sentence case, and labels that describe
  the result rather than the implementation.
- Keep the name of an action consistent across button, progress, confirmation,
  history, and success message.
- Let each label do one job. Avoid decorative technical strings, filler headings,
  and clever copy that makes controls harder to predict.
- Error and empty-state text should explain the condition and the next useful step,
  not apologize or assign blame.

## Rendered review sequence

Review the result in this order so polish does not hide structural defects:

1. **Task:** Can the intended user understand the current context and complete the
   primary job without guessing?
2. **Hierarchy:** Is attention ordered correctly? Are related things grouped and
   competing actions subordinated?
3. **Navigation and platform:** Do Back, close, selection, menus, shortcuts,
   gestures, and window behavior match the target platform and product model?
4. **Content:** Is real, long, empty, failed, loading, permission-limited, and
   localized content handled without clipping or ambiguity?
5. **Accessibility:** Are semantics, names, focus, reading order, alternatives,
   contrast, text scaling, and reduced motion observable and correct?
6. **System:** Are type, color, space, shape, elevation, icons, and motion coherent
   without erasing hierarchy?
7. **Craft:** Fix optical alignment, awkward wrapping, hit areas, cursor behavior,
   transition edges, and theme-specific defects.

Use screenshots or platform previews when available, but interact with the result as
well. Source review cannot reveal every overlay, focus, resize, scrolling, or text
rendering defect.

## Variation review

When multiple concepts were requested, place them side by side without their names
or color explanations. Reject a set if the same wireframe, navigation, density,
surface model, and interaction pattern remain visible underneath. Each surviving
concept should offer a distinct product tradeoff—not merely a different mood—and
should still solve the same core task and accessibility constraints.

## Pre-delivery checklist

Select only the checks applicable to the target, and state what was actually run.

### Product and visual quality

- [ ] Real content and primary tasks shaped the composition.
- [ ] Visual emphasis has a clear order; decoration does not compete with content.
- [ ] Typography, spacing, iconography, surfaces, and feedback form one intentional
      system without uniform card treatment or arbitrary values.
- [ ] Repeated values use existing or justified semantic tokens; no speculative
      component library was added.
- [ ] Requested concepts differ on multiple structural axes.

### States and interaction

- [ ] Relevant hover, press, focus, selection, disabled, loading, empty, error, and
      success states are distinguishable and semantically correct.
- [ ] Actions give prompt feedback; slow or background work remains understandable.
- [ ] Motion is purposeful, interruptible, performant on the target, and usable with
      reduced motion.
- [ ] Destructive and high-cost actions have an appropriate confirmation, undo, or
      recovery path.
- [ ] Back, close, escape, cancellation, and restoration preserve user context.

### Layout and platforms

- [ ] The UI was inspected at relevant minimum, typical, and wide window or viewport
      sizes, plus landscape or split view where applicable.
- [ ] Long text, localization, zoom or dynamic text, content extremes, and virtual
      keyboards do not hide information or actions.
- [ ] Fixed UI respects safe areas and does not cover scroll content or focus.
- [ ] Pointer, touch, keyboard, gestures, menus, selection, and window chrome follow
      the actual target rather than another platform's conventions.
- [ ] Desktop drag regions, text selection, focus, shortcuts, double-click, context
      actions, density, and Back behavior were checked when applicable.

### Accessibility and evidence

- [ ] Native semantics and labels are correct; custom controls implement their full
      interaction pattern.
- [ ] Meaning is not carried by color, motion, position, or gesture alone.
- [ ] Contrast, focus visibility, target sizing, reflow, text scaling, and assistive
      announcements were checked in relevant themes and states.
- [ ] Keyboard and representative assistive-technology paths were exercised where
      available.
- [ ] The delivery distinguishes implemented behavior, static inspection, automated
      checks, manual tests, and untested residual risk.
