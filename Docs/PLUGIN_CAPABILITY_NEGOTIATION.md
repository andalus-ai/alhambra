# Plugin Capability Negotiation

The host gathers capability declarations from discovered plugins and capability
requirements from a composition or plugin. Negotiation selects the highest
available declaration with matching major version and minimum minor version.
Patch versions are compatible.

Missing or incompatible required capabilities block activation. Optional
requirements produce a degraded result. Results include selected providers and
structured diagnostics.

This is a pre-activation compatibility check only. It does not load plugins,
grant permissions, or activate resources. Capability declarations are not
security grants; runtime access remains subject to Alhambra's capability broker.

The initial contract deliberately supports major/minimum-minor constraints,
not a full SemVer range grammar.
