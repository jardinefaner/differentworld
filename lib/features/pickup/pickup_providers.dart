import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One authorized-pickup person attached to a subject. Beyond the
/// child's formal Guardian rows — these are aunts, neighbors, the
/// nanny who covers Wednesdays, etc.
class PickupPerson {
  const PickupPerson({
    required this.name,
    this.phone,
    this.notes,
  });

  factory PickupPerson.fromJson(Map<String, dynamic> json) {
    return PickupPerson(
      name: (json['name'] ?? '').toString(),
      phone: json['phone']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  final String name;
  final String? phone;
  final String? notes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

/// Decode the pickup_people list off a subject's capabilities blob.
List<PickupPerson> pickupPeopleFor(Subject subject) {
  final caps = Capabilities.fromJson(subject.capabilities);
  final raw = caps.get<List<dynamic>>(SubjectCaps.pickupPeople) ?? const [];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map(
        (m) => PickupPerson.fromJson(
          m.map((k, v) => MapEntry(k.toString(), v)),
        ),
      )
      .toList(growable: false);
}

class PickupActions {
  PickupActions(this._ref);

  final Ref _ref;

  Future<void> setPickupPeople({
    required Subject subject,
    required List<PickupPerson> people,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final caps = Capabilities.fromJson(subject.capabilities);
    final updated = caps.setting(
      SubjectCaps.pickupPeople,
      people.map((p) => p.toJson()).toList(),
    );
    await db.updateSubjectCapabilities(subject.id, updated.toJson());
  }
}

final pickupActionsProvider =
    Provider<PickupActions>(PickupActions.new);
