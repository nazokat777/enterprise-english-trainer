import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_english/plan/hook_suggest.dart';

void main() {
  test('tovush ilgaklari', () {
    expect(suggestHook('bucket', meaningUz: 'chelak'), 'buket');
    expect(suggestHook('kettle', meaningUz: 'choynak'), startsWith('ke'));
    expect(suggestHook('book', meaningUz: 'kitob'), startsWith('bu'));
    expect(suggestHook('pillow', meaningUz: 'yostiq'), startsWith('pi'));
    expect(suggestHook('lemon', meaningUz: 'limon'), isNot('limon'));
    expect(suggestHook('x'), '');
  });
  test('taxminiy o\'qilish', () {
    expect(approxSound('phone'), 'fon');
    expect(approxSound('cat'), 'kat');
    expect(approxSound('window'), startsWith('vind'));
  });
}
