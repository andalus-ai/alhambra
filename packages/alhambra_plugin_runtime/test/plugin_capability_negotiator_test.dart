import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
void main(){
 const n=PluginCapabilityNegotiator(), id=CapabilityId('sample.storage');
 test('selects highest compatible provider',(){
 final r=n.negotiate(requirements:const [PluginCapabilityRequirement(id:id,major:2,minimumMinor:1)],declarations:const [
 PluginCapabilityDeclaration(id:id,major:2,minor:1,patch:2),PluginCapabilityDeclaration(id:id,major:2,minor:3)]);
 expect(r.status,CapabilityNegotiationStatus.compatible);expect(r.selected[id]!.version,'2.3.0');
 });
 test('required missing capability blocks activation',(){
 final r=n.negotiate(requirements:const [PluginCapabilityRequirement(id:id,major:1)],declarations:const []);
 expect(r.canActivate,isFalse);expect(r.issues.single.code,'capability_missing');
 });
 test('optional missing capability degrades without blocking',(){
 final r=n.negotiate(requirements:const [PluginCapabilityRequirement(id:id,major:1,required:false)],declarations:const []);
 expect(r.status,CapabilityNegotiationStatus.degraded);expect(r.canActivate,isTrue);
 });
 test('distinguishes unavailable and incompatible providers',(){
 final a=n.negotiate(requirements:const [PluginCapabilityRequirement(id:id,major:1)],declarations:const [PluginCapabilityDeclaration(id:id,major:1,available:false)]);
 final b=n.negotiate(requirements:const [PluginCapabilityRequirement(id:id,major:2)],declarations:const [PluginCapabilityDeclaration(id:id,major:1)]);
 expect(a.issues.single.code,'capability_unavailable');expect(b.issues.single.code,'capability_version_mismatch');
 });
}