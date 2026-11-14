# Alhambra SDK

The Alhambra SDK is the extension-author-facing facade for Alhambra's public
plugin contracts. It re-exports the API package so plugin libraries can use one
stable import.

## Getting started

Add the SDK as a dependency using the version and source appropriate to your
host's Alhambra release. In this repository, packages use local path dependencies
for coordinated development.

```yaml
dependencies:
  alhambra_sdk:
    path: ../alhambra_sdk
```

Import the public SDK:

```dart
import 'package:alhambra_sdk/alhambra_sdk.dart';
```

Implement `AlhambraPlugin` and provide stable `PluginMetadata`. See the
[Plugin Developer Guide](../../Docs/PLUGIN_DEVELOPER_GUIDE.md) for a complete
minimal plugin and host-composition example.

## Package boundary

- This package exposes public plugin API contracts.
- The host application owns plugin selection and runtime composition.
- The host depends on `alhambra_plugin_runtime`; extension libraries should
  avoid depending on runtime internals unless they are also part of the host.
- The SDK does not download, sandbox or isolate plugin code.

## Compatibility

The package's public exports are compatibility-sensitive. Keep examples aligned
with the actual API and SDK constraints. Consult the repository
[developer guidelines](../../Docs/DEVELOPER_GUIDELINES.md) and
[contributing guide](../../CONTRIBUTING.md) before changing public contracts.
