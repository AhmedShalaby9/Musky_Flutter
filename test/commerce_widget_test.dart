import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'widget_test.dart' show FakeApi, start, signIn;

void main() {
  testWidgets('product form sends whole packs and exact EGP minor units', (
    tester,
  ) async {
    final api = FakeApi();
    await start(tester, api);
    await signIn(tester);
    await tester.tap(find.text('Products').first);
    await tester.pumpAndSettle();
    expect(find.text('Tea pack'), findsOneWidget);
    await tester.tap(find.text('Add product'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Product title'),
      'Coffee box',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Product code'),
      'COFFEE',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Stock quantity (packs)'),
      '8',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Pieces per pack'),
      '24',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Price per pack (EGP)'),
      '125.50',
    );
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();
    expect(api.commerceSaved.last['quantity'], 8);
    expect(api.commerceSaved.last['pieces_per_unit'], 24);
    expect(api.commerceSaved.last['unit_price_minor'], 12550);
    await tester.ensureVisible(find.byTooltip('Edit Coffee box'));
    await tester.tap(find.byTooltip('Edit Coffee box'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Stock quantity (packs)'),
      '9',
    );
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();
    expect(api.commerceSaved.last['version'], 1);
    expect(api.commerceSaved.last['method'], 'PATCH');
    await tester.ensureVisible(find.byTooltip('Archive Coffee box'));
    await tester.tap(find.byTooltip('Archive Coffee box'));
    await tester.pumpAndSettle();
    expect(api.commerceSaved.last['active'], false);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'draft invoice selects client and pack lines then posts and voids',
    (tester) async {
      final api = FakeApi();
      await start(tester, api);
      await signIn(tester);
      await tester.tap(find.text('Invoices').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('New invoice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select client'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nile Trading'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add product line'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tea pack'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantity (packs)'),
        '3',
      );
      await tester.pumpAndSettle();
      expect(find.text('Total: EGP 88.50'), findsOneWidget);
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      final save = api.commerceSaved.first;
      expect(save['client_id'], 1);
      expect((save['items'] as List).first['quantity'], 3);
      expect((save['items'] as List).first['unit_price_minor'], 2950);
      expect(find.text('Post invoice'), findsOneWidget);
      await tester.tap(find.text('Post invoice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm posting'));
      await tester.pumpAndSettle();
      expect(api.invoices[1]!['status'], 'posted');
      expect(find.text('Edit draft'), findsNothing);
      await tester.tap(find.text('Void invoice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm void'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a reason.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Reason'),
        'Customer cancelled',
      );
      await tester.tap(find.text('Confirm void'));
      await tester.pumpAndSettle();
      expect(api.invoices[1]!['status'], 'void');
      expect(find.text('Void reason: Customer cancelled'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('product screen fits a compact desktop window', (tester) async {
    final api = FakeApi();
    await start(tester, api, size: const Size(800, 600));
    await signIn(tester);
    await tester.tap(find.byTooltip('Products'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('product buyers button opens clients that bought the item', (
    tester,
  ) async {
    final api = FakeApi();
    await start(tester, api, size: const Size(1600, 900));
    await signIn(tester);
    await tester.tap(find.text('المنتجات').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('شوف مين اشترى الصنف ده من هنا'));
    await tester.tap(find.text('شوف مين اشترى الصنف ده من هنا'));
    await tester.pumpAndSettle();
    expect(find.text('مشتري الصنف'), findsOneWidget);
    expect(find.text('Nile Trading'), findsOneWidget);
    expect(find.text('000003'), findsOneWidget);
    expect(find.text('EGP 1,062.00'), findsOneWidget);
  });
}
