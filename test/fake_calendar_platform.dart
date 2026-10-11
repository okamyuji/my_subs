import 'package:device_calendar_plus_platform_interface/device_calendar_plus_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

typedef FakeEvent = ({
  String? calendarId,
  String title,
  DateTime start,
  DateTime end,
  String? rrule,
  String? reminders,
});

Map<String, dynamic> calendarMap(String id, String name, String accountType) =>
    {
      'id': id,
      'name': name,
      'readOnly': false,
      'isPrimary': false,
      'hidden': false,
      'accountName': 'local',
      'accountType': accountType,
    };

/// In-memory stand-in for the calendar plugin's platform side.
class FakeCalendarPlatform extends DeviceCalendarPlusPlatform
    with MockPlatformInterfaceMixin {
  String permission = 'granted';
  bool failCreateEvent = false;
  Duration delay = Duration.zero;
  final calendars = <Map<String, dynamic>>[];
  final events = <FakeEvent>[];
  final calls = <String>[];
  var _next = 0;

  Future<void> _call(String name) async {
    calls.add(name);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  @override
  Future<String?> requestPermissions(bool writeOnly) async {
    await _call('requestPermissions');
    return permission;
  }

  @override
  Future<String?> hasPermissions() async {
    await _call('hasPermissions');
    return permission;
  }

  @override
  Future<List<Map<String, dynamic>>> listCalendars() async {
    await _call('listCalendars');
    return [...calendars];
  }

  @override
  Future<String> createCalendar(
    String name,
    String? colorHex,
    CreateCalendarPlatformOptions? platformOptions,
  ) async {
    await _call('createCalendar');
    final id = 'c${_next++}';
    calendars.add(calendarMap(id, name, 'LOCAL'));
    return id;
  }

  @override
  Future<void> deleteCalendar(String calendarId) async {
    await _call('deleteCalendar');
    calendars.removeWhere((c) => c['id'] == calendarId);
    events.removeWhere((e) => e.calendarId == calendarId);
  }

  @override
  Future<String> createEvent(
    String? calendarId,
    String title,
    DateTime startDate,
    DateTime endDate,
    bool isAllDay,
    String? description,
    String? location,
    String? url,
    String? timeZone,
    String availability,
    String? recurrenceRule,
    List<int>? reminders,
  ) async {
    await _call('createEvent');
    if (failCreateEvent) throw StateError('write failed');
    events.add((
      calendarId: calendarId,
      title: title,
      start: startDate,
      end: endDate,
      rrule: recurrenceRule,
      reminders: reminders?.join(','),
    ));
    return 'e${events.length}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
