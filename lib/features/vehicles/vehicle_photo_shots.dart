import 'dart:convert';

/// The guided photo shot-list for a vehicle check-in/out (docs/VISION.md —
/// the vehicle guided-photo tangent). Beyond the FACES checklist, the driver
/// walks a named set of shots in a stay-open camera. The list is
/// CONFIGURABLE per vehicle — stored in `vehicles.capabilities` JSON under
/// `photoShots` ({checkout: [...], checkin: [...]}) — and falls back to a
/// sensible default per kind when unset.
///
/// The anchor is the check-in **empty-cabin** shot: a hot-car safety
/// verification (photo proof every child is out). It's `required` by default
/// and a director can't quietly drop it below the floor (see [shotsFor]).
class VehiclePhotoShot {
  const VehiclePhotoShot({
    required this.key,
    required this.label,
    required this.hint,
    this.required = false,
  });

  factory VehiclePhotoShot.fromJson(Map<String, dynamic> j) => VehiclePhotoShot(
    key: j['key'] as String,
    label: j['label'] as String,
    hint: (j['hint'] as String?) ?? '',
    required: j['required'] == true,
  );

  /// Stable id — used in the attachment caption + the storage path. Don't
  /// rename a key once shots exist or old photos lose their label link.
  final String key;
  final String label;
  final String hint;
  final bool required;

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'hint': hint,
    'required': required,
  };
}

/// The safety-critical check-in shot. Always present on check-in even if a
/// custom config omits it — leaving a child in a vehicle is the exact
/// failure this whole feature exists to prevent.
const emptyCabinShot = VehiclePhotoShot(
  key: 'empty_cabin',
  label: 'Empty cabin — every child out',
  hint: 'Walk every row. Photograph the empty seats.',
  required: true,
);

const _defaultCheckout = <VehiclePhotoShot>[
  VehiclePhotoShot(
    key: 'front',
    label: 'Front of the vehicle',
    hint: 'Whole front in frame',
    required: true,
  ),
  VehiclePhotoShot(key: 'rear', label: 'Rear of the vehicle', hint: 'Whole rear in frame'),
  VehiclePhotoShot(
    key: 'odometer',
    label: 'Odometer',
    hint: 'Mileage readable',
    required: true,
  ),
  VehiclePhotoShot(key: 'fuel', label: 'Fuel gauge', hint: 'Needle readable'),
  VehiclePhotoShot(key: 'cabin_ready', label: 'Cabin ready', hint: 'Seats + belts ready'),
];

const _defaultCheckin = <VehiclePhotoShot>[
  VehiclePhotoShot(
    key: 'odometer',
    label: 'Odometer',
    hint: 'Mileage readable',
    required: true,
  ),
  VehiclePhotoShot(key: 'fuel', label: 'Fuel gauge', hint: 'Needle readable'),
  emptyCabinShot,
  VehiclePhotoShot(key: 'damage', label: 'Any new damage', hint: 'Skip if none — or photograph it'),
];

/// Built-in defaults for a kind (a copy of the const list).
List<VehiclePhotoShot> defaultShotsFor(String kind) =>
    List<VehiclePhotoShot>.of(
      kind == 'checkin' ? _defaultCheckin : _defaultCheckout,
    );

/// Resolve the shot-list for [kind] from a vehicle's `capabilities` JSON,
/// falling back to the defaults. On check-in, the empty-cabin safety shot is
/// guaranteed present (re-appended if a custom config dropped it) — the one
/// shot a config can't remove.
List<VehiclePhotoShot> shotsFor(String capabilitiesJson, String kind) {
  List<VehiclePhotoShot> shots;
  try {
    final caps = jsonDecode(capabilitiesJson);
    final byKind = (caps is Map ? caps['photoShots'] : null);
    final list = (byKind is Map ? byKind[kind] : null);
    if (list is List && list.isNotEmpty) {
      shots = [
        for (final s in list)
          if (s is Map) VehiclePhotoShot.fromJson(s.cast<String, dynamic>()),
      ];
    } else {
      shots = defaultShotsFor(kind);
    }
  } on Object {
    shots = defaultShotsFor(kind);
  }
  // Safety floor: check-in always includes the empty-cabin shot.
  if (kind == 'checkin' &&
      !shots.any((s) => s.key == emptyCabinShot.key)) {
    shots = [...shots, emptyCabinShot];
  }
  return shots;
}

/// Write a kind's shot-list back into a `capabilities` JSON string (for the
/// per-vehicle config editor). Preserves any other capability keys.
String withPhotoShots(
  String capabilitiesJson,
  String kind,
  List<VehiclePhotoShot> shots,
) {
  Map<String, dynamic> caps;
  try {
    final decoded = jsonDecode(capabilitiesJson);
    caps = decoded is Map ? decoded.cast<String, dynamic>() : <String, dynamic>{};
  } on Object {
    caps = <String, dynamic>{};
  }
  final photoShots = (caps['photoShots'] is Map)
      ? (caps['photoShots'] as Map).cast<String, dynamic>()
      : <String, dynamic>{};
  photoShots[kind] = [for (final s in shots) s.toJson()];
  caps['photoShots'] = photoShots;
  return jsonEncode(caps);
}
