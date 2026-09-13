import 'package:enterprise_english/services/backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('zaxira nusxa: eksport -> tozalash -> import bir xil holat', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    await p.setInt('xp', 123);
    await p.setBool('dark', true);
    await p.setString('rw_pet', 'Zukko');
    await p.setStringList('rw_ach', ['c10', 'combo10']);
    final text = await Backup.export();
    await p.clear();
    expect(p.getInt('xp'), isNull);
    expect(await Backup.import(text), isTrue);
    expect(p.getInt('xp'), 123);
    expect(p.getBool('dark'), true);
    expect(p.getString('rw_pet'), 'Zukko');
    expect(p.getStringList('rw_ach'), ['c10', 'combo10']);
    expect(await Backup.import('salom'), isFalse);
    expect(await Backup.import('{"format":"x","data":{}}'), isFalse);
  });
}
