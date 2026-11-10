import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

final class PluginCapabilityDeclaration {
 final CapabilityId id; final int major; final int minor; final int patch;
 final bool available; final String? description;
 const PluginCapabilityDeclaration({required this.id,required this.major,this.minor=0,this.patch=0,this.available=true,this.description})
 : assert(major>=0),assert(minor>=0),assert(patch>=0);
 String get version => '$major.$minor.$patch';
}
final class PluginCapabilityRequirement {
 final CapabilityId id; final int major; final int minimumMinor; final bool required;
 const PluginCapabilityRequirement({required this.id,required this.major,this.minimumMinor=0,this.required=true})
 : assert(major>=0),assert(minimumMinor>=0);
}
enum CapabilityNegotiationStatus { compatible,degraded,incompatible }
final class CapabilityNegotiationIssue {
 final CapabilityId capability; final String code,message; final bool blocking;
 const CapabilityNegotiationIssue({required this.capability,required this.code,required this.message,required this.blocking});
}
final class CapabilityNegotiationResult {
 final CapabilityNegotiationStatus status;
 final Map<CapabilityId,PluginCapabilityDeclaration> selected;
 final List<CapabilityNegotiationIssue> issues;
 CapabilityNegotiationResult({required this.status,required Map<CapabilityId,PluginCapabilityDeclaration> selected,required List<CapabilityNegotiationIssue> issues})
 :selected=Map.unmodifiable(selected),issues=List.unmodifiable(issues);
 bool get canActivate=>status!=CapabilityNegotiationStatus.incompatible;
}
/// Pure pre-activation compatibility check; it never loads plugins or grants permissions.
class PluginCapabilityNegotiator {
 const PluginCapabilityNegotiator();
 CapabilityNegotiationResult negotiate({required Iterable<PluginCapabilityRequirement> requirements,required Iterable<PluginCapabilityDeclaration> declarations}) {
  final providers=<CapabilityId,List<PluginCapabilityDeclaration>>{};
  for(final d in declarations){providers.putIfAbsent(d.id,()=>[]).add(d);}
  final selected=<CapabilityId,PluginCapabilityDeclaration>{};
  final issues=<CapabilityNegotiationIssue>[];
  for(final r in requirements){
   final candidates=(providers[r.id]??const <PluginCapabilityDeclaration>[])
    .where((d)=>d.available&&d.major==r.major&&d.minor>=r.minimumMinor).toList()
    ..sort((a,b){final m=b.minor.compareTo(a.minor);return m!=0?m:b.patch.compareTo(a.patch);});
   if(candidates.isNotEmpty){selected[r.id]=candidates.first;continue;}
   final all=providers[r.id]??const <PluginCapabilityDeclaration>[];
   final code=all.isEmpty?'capability_missing':all.every((d)=>!d.available)?'capability_unavailable':'capability_version_mismatch';
   final message=all.isEmpty?'No provider declares ${r.id}.':all.every((d)=>!d.available)?'Providers for ${r.id} are unavailable.':'No available provider satisfies ${r.id} version ${r.major}.${r.minimumMinor}+.';
   issues.add(CapabilityNegotiationIssue(capability:r.id,code:code,message:message,blocking:r.required));
  }
  final blocking=issues.any((i)=>i.blocking);
  return CapabilityNegotiationResult(status:blocking?CapabilityNegotiationStatus.incompatible:issues.isEmpty?CapabilityNegotiationStatus.compatible:CapabilityNegotiationStatus.degraded,selected:selected,issues:issues);
 }
}