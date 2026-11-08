import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

void main() {
  test('application profiles support open capability identifiers', () {
    const profile = ApplicationProfile(
      applicationId: 'com.example.workflow-studio',
      capabilities: {'ui.shell', 'workflow.canvas', 'workflow.run'},
      layoutHints: {'adaptive', 'canvas-first'},
      metadata: {'edition': 'community'},
    );

    expect(profile.applicationId, 'com.example.workflow-studio');
    expect(profile.hasCapability('workflow.canvas'), isTrue);
    expect(profile.hasCapability('coding.editor'), isFalse);
    expect(
      profile.hasAllCapabilities({'ui.shell', 'workflow.canvas'}),
      isTrue,
    );
    expect(
      profile.hasAllCapabilities({'ui.shell', 'coding.editor'}),
      isFalse,
    );
    expect(profile.hasAnyLayoutHint({'canvas-first', 'dense'}), isTrue);
  });

  test('layout requirements separate hard capabilities from preferences', () {
    const profile = ApplicationProfile(
      applicationId: 'com.example.analytics',
      capabilities: {'ui.shell', 'ui.navigation', 'data.visualization'},
      layoutHints: {'adaptive', 'dense'},
    );
    const requirements = LayoutProfileRequirements(
      requiredCapabilities: {'ui.shell', 'data.visualization'},
      preferredHints: {'adaptive', 'navigation-rail'},
    );

    expect(requirements.isCompatibleWith(profile), isTrue);
    expect(requirements.preferenceScore(profile), 1);

    const incompatible = LayoutProfileRequirements(
      requiredCapabilities: {'ui.shell', 'workflow.canvas'},
    );
    expect(incompatible.isCompatibleWith(profile), isFalse);
  });

  test('profile copyWith preserves unspecified values', () {
    const profile = ApplicationProfile(
      applicationId: 'com.example.app',
      capabilities: {'ui.shell'},
      layoutHints: {'adaptive'},
    );

    final updated = profile.copyWith(
      capabilities: {'ui.shell', 'ui.navigation'},
    );

    expect(updated.applicationId, profile.applicationId);
    expect(updated.capabilities, {'ui.shell', 'ui.navigation'});
    expect(updated.layoutHints, {'adaptive'});
  });
  test('layout metadata exposes profile compatibility and preference score', () {
    const profile = ApplicationProfile(
      applicationId: 'com.example.dashboard',
      capabilities: {'ui.shell', 'ui.navigation', 'data.visualization'},
      layoutHints: {'dashboard', 'dense-grid'},
    );
    const metadata = LayoutPluginMetadata(
      id: 'com.example.layout.analytics',
      name: 'Analytics',
      description: 'Data dashboard layout',
      icon: Icons.dashboard,
      profileRequirements: LayoutProfileRequirements(
        requiredCapabilities: {'ui.shell', 'data.visualization'},
        preferredHints: {'dashboard', 'dense-grid'},
      ),
    );

    expect(metadata.isCompatibleWith(profile), isTrue);
    expect(metadata.preferenceScore(profile), 2);
    expect(
      metadata.isCompatibleWith(
        const ApplicationProfile(
          applicationId: 'com.example.mobile',
          capabilities: {'ui.shell', 'ui.navigation'},
        ),
      ),
      isFalse,
    );
  });

}
