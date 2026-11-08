/// The scope at which a permission is evaluated.
///
/// Scopes establish a hierarchy — platform is the broadest, resource is
/// the most granular:
///
/// ```text
/// platform
///    └── organization
///           └── team
///                  └── resource
/// ```
///
/// Using scopes allows authorization decisions to be made at the
/// appropriate granularity without requiring Alhambra to know the
/// application's specific resource topology.
enum AccessScope {
  /// Affects all organizations and resources on the platform.
  platform,

  /// Scoped to a specific organization and its members.
  organization,

  /// Scoped to a team within an organization.
  team,

  /// Scoped to an individual resource instance.
  resource,
}
