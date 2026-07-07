// TabRobot — drives any of the example's op tabs.
//
// App-specific: knows every operation is an OpButton keyed
// 'op:<label>', every tab body is one vertical ListView, results land
// in the tab's log pane, and text inputs are labeled TextFields. One
// robot serves all seven tabs because the tabs share this structure.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/pump_strategies.dart';
import '../harness/robot.dart';

class TabRobot extends Robot {
  TabRobot(super.tester);

  /// The ACTIVE tab body's ListView scrollable.
  ///
  /// Three impostors make a naive byType(Scrollable) ambiguous: the
  /// TabBar and TabBarView pager (horizontal — excluded by axis), every
  /// TextField's inner editable (horizontal — excluded by axis), and
  /// kept-alive neighbor pages' ListViews (excluded by hitTestable:
  /// they're laid out but clipped outside the pager's viewport).
  Finder get _bodyList => find
      .byWidgetPredicate(
        (w) =>
            w is Scrollable &&
            axisDirectionToAxis(w.axisDirection) == Axis.vertical,
      )
      .hitTestable()
      .first;

  /// Tap the operation button labeled [label] (keyed 'op:<label>').
  ///
  /// Deliberately NOT the harness scrollToAndTap: its ensureVisible step
  /// propagates the reveal request up the ancestor chain into the
  /// TabBarView pager, which jolts the tab machinery's muted tickers and
  /// trips AnimationController's elapsed >= 0 assertion (the
  /// flutter/flutter#43501 family). Op buttons here are compact, so
  /// scrollUntilVisible alone brings the whole button on-screen —
  /// centering is only needed for children taller than the viewport.
  Future<void> tapOp(String label) async {
    // Re-home to the top first: scrollUntilVisible only searches
    // DOWNWARD, and expectLog leaves the list parked at the bottom.
    await tester.drag(_bodyList, const Offset(0, 10000));
    await settle();
    final target = find.byKey(ValueKey('op:$label'));
    await tester.scrollUntilVisible(target, 120, scrollable: _bodyList);
    // Settle BEFORE tapping: a tap during leftover fling momentum is
    // awarded to the scrollable as a stop-gesture, not to the button.
    await settle();
    await tester.tap(target);
    await settle();
  }

  /// Type [text] into the TextField labeled [label].
  Future<void> enterField(String label, String text) async {
    final field = find.widgetWithText(TextField, label);
    await tester.scrollUntilVisible(field, 120, scrollable: _bodyList);
    await tester.enterText(field, text);
    await settle();
  }

  /// Wait until the tab's log pane contains [text] — the assertion
  /// surface for every operation. On the journeys' memory disk the op's
  /// IO completes as microtasks, so plain pumping is enough — and it
  /// never hangs on a spinner. A timeout reports what the log actually
  /// said, so a failure reads as actual-vs-expected.
  ///
  /// Scrolls to the bottom of the tab first: the log pane is the LAST
  /// section of a lazy ListView, so on small devices it is never even
  /// BUILT until scrolled to — a finder can't see an unbuilt widget.
  Future<void> expectLog(String text) async {
    await tester.drag(_bodyList, const Offset(0, -10000));
    await settle();
    try {
      await pumpUntil(
        tester,
        () => tester.any(find.textContaining(text)),
        describe: 'log line "$text"',
      );
    } on TestFailure {
      final logs = tester
          .widgetList<Text>(
            find.byWidgetPredicate(
              (w) =>
                  w is Text && (w.data?.contains('✓') ?? false) ||
                  w is Text && (w.data?.contains('✗') ?? false),
            ),
          )
          .map((t) => t.data)
          .join(' | ');
      throw TestFailure(
        'expected log line "$text" never appeared.\n'
        'Log pane currently shows: ${logs.isEmpty ? '(nothing)' : logs}',
      );
    }
  }
}
