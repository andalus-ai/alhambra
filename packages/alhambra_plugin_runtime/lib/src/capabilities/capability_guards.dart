import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

class CapabilityAuditRecord {
  final DateTime timestamp;
  final CapabilityId capability;
  final String pluginId;
  final CapabilityDecision decision;
  final String? reason;
  final Map<String, Object?> details;

  CapabilityAuditRecord({
    DateTime? timestamp,
    required this.capability,
    required this.pluginId,
    required this.decision,
    this.reason,
    this.details = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      '[$timestamp] $pluginId -> ${capability.value}: ${decision.name} ${reason != null ? '($reason)' : ''}';
}

class CapabilityAuditLog {
  final List<CapabilityAuditRecord> _records = [];
  final _recordStreamController =
      StreamController<CapabilityAuditRecord>.broadcast();

  Stream<CapabilityAuditRecord> get onRecord => _recordStreamController.stream;
  List<CapabilityAuditRecord> get records => List.unmodifiable(_records);

  void record({
    required CapabilityId capability,
    required String pluginId,
    required CapabilityDecision decision,
    String? reason,
    Map<String, Object?> details = const {},
  }) {
    final entry = CapabilityAuditRecord(
      capability: capability,
      pluginId: pluginId,
      decision: decision,
      reason: reason,
      details: details,
    );
    _records.add(entry);
    _recordStreamController.add(entry);
  }

  void clear() => _records.clear();
}

class CommandCapabilityGuard {
  final CapabilityAccess capabilityAccess;
  final CapabilityAuditLog? auditLog;

  const CommandCapabilityGuard({required this.capabilityAccess, this.auditLog});

  Future<void> checkExecution({
    required String commandId,
    required String pluginId,
  }) async {
    const requiredCap = StandardCapabilities.commandsExecute;
    final isAllowed = capabilityAccess.canUse(requiredCap);

    auditLog?.record(
      capability: requiredCap,
      pluginId: pluginId,
      decision: isAllowed
          ? CapabilityDecision.allowed
          : CapabilityDecision.denied,
      details: {'commandId': commandId},
    );

    if (!isAllowed) {
      throw CapabilityException(
        capability: requiredCap,
        message:
            'Execution of command "$commandId" denied for plugin "$pluginId".',
      );
    }
  }
}

class ViewCapabilityGuard {
  final CapabilityAccess capabilityAccess;
  final CapabilityAuditLog? auditLog;

  const ViewCapabilityGuard({required this.capabilityAccess, this.auditLog});

  bool canContributeView({required String viewId, required String pluginId}) {
    const requiredCap = StandardCapabilities.uiViews;
    final isAllowed = capabilityAccess.canUse(requiredCap);

    auditLog?.record(
      capability: requiredCap,
      pluginId: pluginId,
      decision: isAllowed
          ? CapabilityDecision.allowed
          : CapabilityDecision.denied,
      details: {'viewId': viewId},
    );

    return isAllowed;
  }
}

class StorageCapabilityGuard {
  final CapabilityAccess capabilityAccess;
  final CapabilityAuditLog? auditLog;

  const StorageCapabilityGuard({required this.capabilityAccess, this.auditLog});

  void checkRead({required String key, required String pluginId}) {
    const requiredCap = StandardCapabilities.filesRead;
    final isAllowed = capabilityAccess.canUse(requiredCap);

    auditLog?.record(
      capability: requiredCap,
      pluginId: pluginId,
      decision: isAllowed
          ? CapabilityDecision.allowed
          : CapabilityDecision.denied,
      details: {'storageKey': key, 'operation': 'read'},
    );

    if (!isAllowed) {
      throw CapabilityException(
        capability: requiredCap,
        message: 'Storage read for key "$key" denied for plugin "$pluginId".',
      );
    }
  }

  void checkWrite({required String key, required String pluginId}) {
    const requiredCap = StandardCapabilities.filesWrite;
    final isAllowed = capabilityAccess.canUse(requiredCap);

    auditLog?.record(
      capability: requiredCap,
      pluginId: pluginId,
      decision: isAllowed
          ? CapabilityDecision.allowed
          : CapabilityDecision.denied,
      details: {'storageKey': key, 'operation': 'write'},
    );

    if (!isAllowed) {
      throw CapabilityException(
        capability: requiredCap,
        message: 'Storage write for key "$key" denied for plugin "$pluginId".',
      );
    }
  }
}

class NetworkCapabilityGuard {
  final CapabilityAccess capabilityAccess;
  final CapabilityAuditLog? auditLog;

  const NetworkCapabilityGuard({required this.capabilityAccess, this.auditLog});

  void checkAccess({required Uri uri, required String pluginId}) {
    const requiredCap = StandardCapabilities.network;
    final grant = capabilityAccess.getGrant(requiredCap);

    if (grant == null || grant.isDenied) {
      auditLog?.record(
        capability: requiredCap,
        pluginId: pluginId,
        decision: CapabilityDecision.denied,
        details: {'host': uri.host, 'uri': uri.toString()},
      );
      throw CapabilityException(
        capability: requiredCap,
        message:
            'Network request to "${uri.host}" denied for plugin "$pluginId".',
      );
    }

    if (grant.isConditional) {
      // Validate host constraints if specified
      for (final constraint in grant.constraints) {
        if (constraint.type == 'allowed_hosts') {
          final allowed = constraint.parameters['hosts'] as List<dynamic>?;
          if (allowed != null && !allowed.contains(uri.host)) {
            auditLog?.record(
              capability: requiredCap,
              pluginId: pluginId,
              decision: CapabilityDecision.denied,
              details: {
                'host': uri.host,
                'reason': 'Host not in allowed_hosts',
              },
            );
            throw CapabilityException(
              capability: requiredCap,
              message:
                  'Host "${uri.host}" is not in the allowed hosts constraint for plugin "$pluginId".',
            );
          }
        }
      }
    }

    auditLog?.record(
      capability: requiredCap,
      pluginId: pluginId,
      decision: CapabilityDecision.allowed,
      details: {'host': uri.host},
    );
  }
}
