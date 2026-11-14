# Instructions for Alhambra examples

Examples are executable learning material and should stay aligned with the
published public contracts.

## Rules
- Prefer small, runnable examples over pseudo-code presented as production code.
- Pin the intended package relationship with explicit local path dependencies
  for in-repository examples.
- Use only public package exports unless the example explicitly teaches an
  internal implementation detail.
- Keep examples product-neutral and avoid coupling to Alhambra consumer apps.
- State prerequisites, exact run/test commands, expected behavior and known
  limitations in each example README.
- Distinguish host responsibilities from plugin responsibilities.
- Never imply that plugin registration provides sandboxing, dynamic code
  loading, permission grants or durable exactly-once effects.
- Keep secrets, real credentials and production endpoints out of examples.

## Quality
- Add a test for lifecycle and cleanup behavior when the example demonstrates
  runtime composition.
- Verify contribution ownership and cleanup, not just successful construction.
- Keep snippets formatted and compile-checked with the supported SDK.
- Update the examples index and relevant developer guide when adding examples.
- Report commands that were not run; do not claim an example was executed
  unless dependency resolution and execution were actually verified.
