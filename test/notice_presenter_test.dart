import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/platform/notice_presenter.dart';
import 'package:okul_zili/platform/notifier.dart';

class _FakeToast implements ToastNotifier {
  _FakeToast({this.fail = false});
  final bool fail;
  final shown = <String>[];

  @override
  Future<void> init() async {}

  @override
  Future<void> show(String title, String body) async {
    shown.add('$title|$body');
    if (fail) throw StateError('toast');
  }
}

void main() {
  late List<String> tips;
  late int inactiveCalls;

  NoticePresenter make(ToastNotifier toast, {required bool visible}) {
    tips = [];
    inactiveCalls = 0;
    return NoticePresenter(
      setToolTip: (t) async => tips.add(t),
      isWindowVisible: () async => visible,
      showInactive: () async => inactiveCalls++,
      toast: toast,
    );
  }

  test('pencere gizliyken ipucu, toast ve showInactive', () async {
    final toast = _FakeToast();
    await make(toast, visible: false).present('Ses', 'ayrıntı');
    expect(tips, ['Okul Zili — DİKKAT: Ses']);
    expect(toast.shown, ['Ses|ayrıntı']);
    expect(inactiveCalls, 1);
  });

  test('pencere görünürken yalnız ipucu', () async {
    final toast = _FakeToast();
    await make(toast, visible: true).present('Ses', 'ayrıntı');
    expect(tips, ['Okul Zili — DİKKAT: Ses']);
    expect(toast.shown, isEmpty);
    expect(inactiveCalls, 0);
  });

  test('toast fırlatırsa ipucu ve showInactive yine çağrılır', () async {
    final toast = _FakeToast(fail: true);
    await make(toast, visible: false).present('Ses', 'ayrıntı');
    expect(tips, hasLength(1));
    expect(inactiveCalls, 1);
  });

  test('NoopToastNotifier fırlatmaz', () async {
    const noop = NoopToastNotifier();
    await noop.init();
    await noop.show('a', 'b');
  });
}
