import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../data/backend_providers.dart';
import '../models/skill_entity.dart';

final skillsListProvider =
    FutureProvider.autoDispose<List<SkillEntity>>((ref) async {
  final backend = ref.watch(backendServiceProvider);
  final data = await backend.listSkills();
  return data.map((e) => SkillEntity.fromJson(e)).toList();
});

final trashedSkillsProvider =
    FutureProvider.autoDispose<List<SkillEntity>>((ref) async {
  final backend = ref.watch(backendServiceProvider);
  final data = await backend.listTrashedSkills();
  return data.map((e) => SkillEntity.fromJson(e)).toList();
});

final skillDetailProvider =
    FutureProvider.autoDispose.family<SkillEntity, String>((ref, id) async {
  final backend = ref.watch(backendServiceProvider);
  final data = await backend.getSkill(id);
  return SkillEntity.fromJson(data);
});

class SkillsController extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  SkillsController(this.ref) : super(const AsyncValue.data(null));

  Future<void> reloadSkills() async {
    state = const AsyncValue.loading();
    try {
      final backend = ref.read(backendServiceProvider);
      await backend.reloadSkills();
      ref.invalidate(skillsListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> saveSkill(SkillEntity skill, {bool isNew = false}) async {
    state = const AsyncValue.loading();
    try {
      final backend = ref.read(backendServiceProvider);
      if (isNew) {
        await backend.createSkill(skill.toJson());
      } else {
        await backend.updateSkill(skill.id, skill.toJson());
      }
      ref.invalidate(skillsListProvider);
      ref.invalidate(skillDetailProvider(skill.id));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> softDeleteSkill(String id) async {
    try {
      final backend = ref.read(backendServiceProvider);
      await backend.deleteSkill(id);
      ref.invalidate(skillsListProvider);
      ref.invalidate(trashedSkillsProvider);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> restoreSkill(String id) async {
    try {
      final backend = ref.read(backendServiceProvider);
      await backend.restoreSkill(id);
      ref.invalidate(skillsListProvider);
      ref.invalidate(trashedSkillsProvider);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> hardDeleteSkill(String id) async {
    try {
      final backend = ref.read(backendServiceProvider);
      await backend.deleteSkill(id, hard: true);
      ref.invalidate(trashedSkillsProvider);
    } catch (e) {
      // Handle error
    }
  }
}

final skillsControllerProvider =
    StateNotifierProvider<SkillsController, AsyncValue<void>>((ref) {
  return SkillsController(ref);
});
