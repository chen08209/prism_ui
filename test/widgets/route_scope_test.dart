import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';
import '../helpers/test_app.dart';

class _HeldPage extends StatefulWidget {
  const _HeldPage();

  @override
  State<_HeldPage> createState() => _HeldPageState();
}

class _HeldPageState extends State<_HeldPage>
    with RouteMotionHoldMixin<_HeldPage> {
  final applied = <String>[];

  void schedule(String label, {Object? key}) {
    if (key == null) {
      updateWhenRouteSettled(() => applied.add(label));
    } else {
      updateWhenRouteSettled(() => applied.add(label), key: key);
    }
  }

  @override
  Widget build(BuildContext context) => const Text('held');
}

void main() {
  testWidgets('a page holding for its route is not rebuilt as another page '
      'covers and uncovers it', (tester) async {
    await tester.pumpWidget(const HostApp(home: _HeldPage()));
    var rebuilds = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is _HeldPage) {
        rebuilds++;
      }
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);

    final navigator = Navigator.of(tester.element(find.text('held')));
    unawaited(
      navigator.push(CardPageRoute<void>(builder: (_) => const Text('cover'))),
    );
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();
    debugOnRebuildDirtyWidget = null;

    expect(rebuilds, 0);
  });

  testWidgets('a page in a navigator inside a page finds its own route', (
    tester,
  ) async {
    final inner = PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const Text('inner'),
    );
    await tester.pumpWidget(
      HostApp(home: Navigator(onGenerateRoute: (_) => inner)),
    );

    expect(routeOf(tester.element(find.text('inner'))), same(inner));
  });

  testWidgets('a page finds the route that built it', (tester) async {
    await tester.pumpWidget(const HostApp(home: Text('home')));
    final route = CardPageRoute<void>(builder: (_) => const Text('pushed'));
    unawaited(Navigator.of(tester.element(find.text('home'))).push(route));
    await tester.pumpAndSettle();

    expect(routeOf(tester.element(find.text('pushed'))), same(route));
  });

  testWidgets('RouteMotionHoldMixin replays each held key independently', (
    tester,
  ) async {
    await tester.pumpWidget(const HostApp(home: _HeldPage()));
    final state = tester.state<_HeldPageState>(find.byType(_HeldPage));
    final navigator = Navigator.of(tester.element(find.byType(_HeldPage)));

    navigator.didStartUserGesture();
    await tester.pump();
    state.schedule('a1', key: 'a');
    state.schedule('a2', key: 'a');
    state.schedule('b1', key: 'b');
    expect(state.applied, isEmpty);

    navigator.didStopUserGesture();
    await tester.pump();
    expect(state.applied, ['a2', 'b1']);
  });
}
