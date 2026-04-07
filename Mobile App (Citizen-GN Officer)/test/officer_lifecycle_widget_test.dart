import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:govease/utils/officer_policy_utils.dart';

class _LifecycleActionsView extends StatelessWidget {
  const _LifecycleActionsView({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final actions = officerApplicationLifecycleActions(status);
    return MaterialApp(
      home: Scaffold(
        body: Column(children: actions.map((action) => Text(action)).toList()),
      ),
    );
  }
}

void main() {
  testWidgets('submitted applications expose expected lifecycle actions', (
    tester,
  ) async {
    await tester.pumpWidget(const _LifecycleActionsView(status: 'Submitted'));

    expect(find.text('review'), findsOneWidget);
    expect(find.text('start_review'), findsOneWidget);
    expect(find.text('reject'), findsOneWidget);
    expect(find.text('complete'), findsNothing);
  });

  testWidgets('processing applications expose completion action', (
    tester,
  ) async {
    await tester.pumpWidget(const _LifecycleActionsView(status: 'Processing'));

    expect(find.text('review'), findsOneWidget);
    expect(find.text('complete'), findsOneWidget);
    expect(find.text('reject'), findsOneWidget);
    expect(find.text('start_review'), findsNothing);
  });
}
