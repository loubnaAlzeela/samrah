/// The Colyseus msgpack wire format does not distinguish int/double the way
/// Dart's `as int` cast expects — whole numbers can arrive decoded as
/// `double` (e.g. `serverNow`, `turnDeadline`, any score/count). A bare
/// `json['x'] as int` then throws `type 'double' is not a subtype of type
/// 'int'` at runtime. Every numeric field in the wire protocol must go
/// through these helpers instead of a raw cast.
library;

int asInt(Object? v) => (v as num).toInt();
int? asIntOrNull(Object? v) => v == null ? null : (v as num).toInt();
int asIntOr(Object? v, int fallback) => v == null ? fallback : (v as num).toInt();
