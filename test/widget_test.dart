import 'package:flutter_test/flutter_test.dart';
import 'package:socekt_demo/main.dart';

void main() {
  testWidgets('Geofence attendance smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GeofenceAttendanceApp());

    // Verify that title is displayed.
    expect(find.text('GeoAttendance'), findsWidgets);
  });
}
