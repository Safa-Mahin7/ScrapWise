// ScrapWise — Phase 1 widget smoke tests.
//
// These tests verify that the app boots without crashing and that
// key widgets from the core library render correctly in isolation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapwise/core/widgets/sw_button.dart';
import 'package:scrapwise/core/widgets/sw_error_widget.dart';
import 'package:scrapwise/core/widgets/sw_loading.dart';
import 'package:scrapwise/core/widgets/sw_text_field.dart';
import 'package:scrapwise/core/theme/app_theme.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('SwButton', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(_wrap(
        SwButton(label: 'Tap me', onPressed: () {}),
      ));
      expect(find.text('Tap me'), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLoading=true', (tester) async {
      await tester.pumpWidget(_wrap(
        SwButton(label: 'Loading', onPressed: () {}, isLoading: true),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders as OutlinedButton when isOutlined=true', (tester) async {
      await tester.pumpWidget(_wrap(
        SwButton(label: 'Outlined', onPressed: () {}, isOutlined: true),
      ));
      expect(find.byType(OutlinedButton), findsOneWidget);
    });
  });

  group('SwTextField', () {
    testWidgets('renders with label', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_wrap(
        SwTextField(controller: controller, label: 'Mobile Number'),
      ));
      expect(find.text('Mobile Number'), findsOneWidget);
      controller.dispose();
    });

    testWidgets('shows visibility toggle for password field', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_wrap(
        SwTextField(
          controller: controller,
          label: 'Password',
          obscureText: true,
        ),
      ));
      // visibility icon should appear
      expect(find.byType(IconButton), findsOneWidget);
      controller.dispose();
    });
  });

  group('SwLoadingIndicator', () {
    testWidgets('renders CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_wrap(const SwLoadingIndicator()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('SwErrorWidget', () {
    testWidgets('renders error message', (tester) async {
      await tester.pumpWidget(_wrap(
        const SwErrorWidget(message: 'Oops! Something went wrong.'),
      ));
      expect(find.text('Oops! Something went wrong.'), findsOneWidget);
    });

    testWidgets('renders retry button when onRetry provided', (tester) async {
      await tester.pumpWidget(_wrap(
        SwErrorWidget(
          message: 'Error',
          onRetry: () {},
          retryLabel: 'Try Again',
        ),
      ));
      expect(find.text('Try Again'), findsOneWidget);
    });
  });
}
