# Alhambra UI Package Boundaries

`alhambra_ui` is a presentation foundation. It must not require an application
identity provider, domain workspace model, search backend, or platform service
container merely to render reusable widgets.

## Dependency rule

The core UI package may depend on Flutter and small presentation-safe
foundations such as `alhambra_core`. It must not require:

- `alhambra_identity` for authorization state;
- `alhambra_workspace` for workspace domain lifecycle and identifiers;
- `alhambra_services` for search, events, notifications, or service lookup.

Applications and optional adapters own those integrations and pass data or
callbacks into widgets.

## Search integration

Search widgets now accept an application callback and UI DTO:

```dart
SearchOverlay.show(
  context,
  onSearch: (query, {scopeId}) async {
    final response = await searchService.search(
      SearchQuery(text: query, scope: scopeFromId(scopeId)),
    );
    return response.results.map((item) => UiSearchResult(
      resourceId: item.resourceId,
      resourceType: item.resourceType,
      title: item.title,
      description: item.description,
    )).toList();
  },
);
```

The example is an adapter at the application boundary. The UI package does
not know what a `SearchService`, tenant, organization, or resource repository
is. The host is responsible for authorization and scope enforcement.

## Workspace presentation

Workspace widgets use `String` as an opaque identifier and
`UiWorkspaceStatus` as a presentation-only lifecycle label:

```dart
WorkspaceShell(
  workspaceId: domainWorkspace.id.value,
  title: domainWorkspace.name,
  status: UiWorkspaceStatus.values.byName(domainWorkspace.status.name),
  child: const WorkspaceOverview(),
);
```

Applications map their domain lifecycle into the presentation enum. The
presentation enum is intentionally not a lifecycle state machine and does not
perform transitions or authorization.

## Migration notes

This changes the public widget API:
- `SearchOverlay` now requires `onSearch` instead of `SearchService`.
- `SearchResultsView` consumes `UiSearchResult`.
- `WorkspaceHeader` and `WorkspaceShell` consume `UiWorkspaceStatus`.
- `WorkspaceShell.workspaceId` is now an opaque string; pass
  `WorkspaceId.value` from the domain package.

The package is currently unpublished (`publish_to: none`), so this is the
right point to establish the boundary before downstream consumers stabilize.
Optional integration adapters can be introduced as separate packages without
reintroducing mandatory dependencies into `alhambra_ui`.
