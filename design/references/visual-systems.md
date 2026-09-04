# Visual and system foundations

Licensing note: this file contains substantially modified material derived from
Anthropic's `frontend-design` skill. See
[Third-Party Notices](../THIRD_PARTY_NOTICES.md).

Read this reference when creating a visual direction, defining a design system, or
reviewing hierarchy and consistency. Treat every value below as a decision axis,
not a prescribed aesthetic.

## Start with hierarchy

Rank what the user must notice, understand, and do. Express that order with a
coordinated use of position, grouping, alignment, scale, weight, contrast, and
space. One screen should not contain several elements competing at the same highest
emphasis.

- Let proximity show relationships before adding containers or dividers.
- Use alignment to connect items across a view and deliberate breaks in alignment
  only to create meaningful emphasis.
- Use borders, fills, shadows, labels, numbering, and badges only when they encode
  grouping, state, sequence, or affordance.
- Avoid turning every piece of content into an identical card. Different roles need
  different visual weight; some content needs no surface at all.
- Keep the primary action discoverable, but do not manufacture a primary call to
  action on screens whose job is inspection, comparison, or background status.

Sketch the content and task flow before decorating it. For competing directions,
compare simple wireframes so structural differences are visible without color.

## Typography

Choose type for the audience, reading conditions, platform, language coverage, and
product character. A system family may be the most native choice; a custom family
is justified only when its personality or functional qualities earn its loading and
rendering cost.

- Define a small set of roles such as display, title, body, label, and data, with
  deliberate size, weight, line height, and spacing relationships.
- Preserve readable measure for prose and allow labels, headings, identifiers, and
  translated strings to wrap or disclose their full value appropriately.
- Use hierarchy instead of habitual uppercase eyebrows, arbitrary monospace labels,
  or a single accent word in every heading.
- Use tabular figures where changing number widths would disrupt comparison or
  alignment. Align numerical columns by their meaning, not merely their bounding
  boxes.
- Support system text scaling on native platforms and browser zoom/reflow on the
  web. Do not make a fixed-height container responsible for clipping text.
- Load only the faces and weights the product uses and account for fallback metrics
  so text remains visible and layout shift is limited.

Judge type in the real script and content. Font pairings that work for an English
marketing headline may fail for dense UI, Cyrillic, long labels, or numeric data.

## Color and surfaces

Build color around functional roles: canvas, surface, elevated or selected surface,
primary and secondary text, border, accent, focus, and semantic feedback. Separate
the raw palette from semantic roles when the system has more than one theme or
product surface.

- Use contrast to establish hierarchy without letting low-emphasis text become
  unreadable.
- Never rely on hue alone for status, selection, errors, charts, or required fields;
  pair it with text, shape, iconography, pattern, or position.
- Design light, dark, high-contrast, and branded themes as mappings of the same
  semantic roles. Test each composed foreground/background pair independently;
  inversion is not a theme strategy.
- Use translucency, blur, gradients, and shadows only when they support depth,
  separation, focus, or the chosen visual language. Verify the composed result over
  real content.
- Keep elevation and shape vocabularies small enough to remain meaningful. Repeating
  one radius or shadow on every object erases hierarchy as surely as random values.

## Spacing, density, and composition

Choose a base rhythm appropriate to the platform and content, then define a small
scale rather than scattering unrelated values. Optical adjustment is allowed when
mathematical equality looks wrong.

- Inner gaps are normally tighter than gaps between groups; section breaks should
  be visibly stronger than item spacing.
- Density follows task frequency, input precision, display size, and user expertise.
  A desktop workbench may be compact without becoming cramped; a touch interface
  needs larger hit areas without making every visual element enormous.
- Keep long-form content within a readable measure while allowing tables, timelines,
  canvases, and inspectors to use width according to their jobs.
- Reserve space for asynchronous content and media to avoid disruptive movement.
- Use grids as alignment systems, not as a demand for equal columns or symmetric
  composition. Asymmetry is useful when it reinforces priority.

## Iconography and imagery

Choose one coherent icon language per hierarchy level: compatible stroke, fill,
corner, perspective, and optical size. Use official brand assets when brands are
shown; do not redraw or recolor them from memory.

- An icon beside equivalent visible text is usually decorative to assistive
  technology. A standalone meaningful icon needs a text alternative; an icon button
  needs an accessible name and any relevant state.
- Do not use emoji as generic structural controls. Emoji can still be valid user
  content or part of an explicitly chosen visual language.
- Align icons optically with their neighboring text and keep their visible size
  separate from the control's interaction target.
- Use imagery because it provides subject matter, evidence, orientation, or mood;
  do not add interchangeable stock decoration merely to fill a layout.

## Design-system depth

Systemize only what will recur.

1. Use primitives for raw values that need controlled reuse.
2. Map them to semantic roles that express intent across themes and platforms.
3. Add component-level tokens only where a component has a legitimate independent
   contract; avoid aliases for every property.

Specify a reusable component through anatomy, content rules, behavior, states,
variants, layout constraints, and accessibility—not only colors and dimensions.
Prefer composition over a growing matrix of boolean options. Treat token and
component changes as interface changes when downstream consumers depend on them.

Before creating new foundations, inventory the existing ones. Consolidate accidental
variation, but preserve deliberate exceptions and offer migration paths when a
shared token or component changes meaning.

## Data-dense interfaces

Select a table or chart from the comparison task, not visual novelty. Make units,
time range, sorting, filtering, selection, and empty/error states explicit. Use
locale-aware formats and stable number alignment. Charts need a nearby legend or
direct labels, keyboard/touch access to interactive values, and a text or table
alternative for the underlying information. Reduce marks or aggregate at small
sizes rather than shrinking labels beyond readability.

## Detect templated output

After forming a direction, ask which choices could be pasted unchanged into an
unrelated product. Audit for defaults that recur regardless of subject, such as a
warm cream-and-terracotta palette, near-black with one acid accent, hairline
editorial columns, or a rounded-card kit that repeats one radius and soft shadow.
Also question tracked uppercase eyebrows above every heading, monospace
micro-labels, middle-dot metadata strings, `WORD — fragment` labels, decorative
arrows appended to most actions, identical spacing at every hierarchy, and generic
dashboard or landing-page chrome.

These are warning signs, not banned treatments. When the brief deliberately calls
for one, the brief wins. Otherwise rework the default using the product's content,
material, workflow, and platform, and record what became more specific.
