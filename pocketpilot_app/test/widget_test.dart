import 'package:flutter_test/flutter_test.dart';
import 'package:pocketpilot_app/main.dart';

void main() {
  testWidgets('App launches and shows pairing screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PocketPilotApp());
    
    // Verify the app title is shown
    expect(find.text('PocketPilot'), findsOneWidget);
    expect(find.text('Remote Laptop Control'), findsOneWidget);
    
    // Verify connection fields exist
    expect(find.text('Laptop IP Address'), findsOneWidget);
    expect(find.text('Pairing Token'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });
}