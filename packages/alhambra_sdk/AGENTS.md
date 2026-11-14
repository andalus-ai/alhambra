# Instructions for alhambra_sdk

This package is the extension-author-facing convenience surface over Alhambra's
public plugin contracts.

## Ownership
- Re-export stable public contracts rather than duplicating their definitions.
- Keep host-only runtime implementation details out of the SDK surface.
- Keep examples product-neutral and runnable against the declared SDK constraints.
- Do not imply that the SDK downloads, sandboxes or securely isolates plugin code.

## Developer experience
- Prefer small, discoverable APIs with clear migration guidance.
- Keep README examples aligned with actual exported symbols and package versions.
- Document which operations are performed by the host and which by plugin code.
- Explain capability declaration versus authorization and the compiled-plugin trust boundary.

## Validation
- Verify imports against the SDK barrel and path dependencies.
- Keep example code formatted and compile-checked where practical.
- Update package README, changelog and central Docs index for public API changes.
