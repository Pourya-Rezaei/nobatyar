import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nobatyar/app_data.dart';
import 'package:nobatyar/jalali.dart';
import 'package:nobatyar/main.dart';
import 'package:nobatyar/models.dart';
import 'package:nobatyar/storage.dart';

/// بارگذاری فونت واقعی وزیرمتن برای رندر درست متن فارسی در تست
Future<void> _loadFonts() async {
  const weights = ['Regular', 'Medium', 'SemiBold', 'Bold'];
  for (final w in weights) {
    final bytes = File('assets/fonts/Vazirmatn-$w.ttf').readAsBytesSync();
    final loader = FontLoader('Vazirmatn')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

AppData _demoData() {
  final today = todayJalali();
  final store = MemoryStore(
    settings: BizSettings(
      name: 'کلینیک زیبایی رز',
      type: BusinessType.beautyClinic,
    ),
    seed: [
      Appt(
        id: 'a1',
        name: 'سارا محمدی',
        phone: '09121234567',
        service: 'پاکسازی پوست',
        dateKey: today.dateKey,
        time: 9 * 60 + 30,
        status: ApptStatus.confirmed,
        createdAt: 1,
      ),
      Appt(
        id: 'a2',
        name: 'نگار کریمی',
        service: 'لیزر موهای زائد',
        dateKey: today.dateKey,
        time: 11 * 60,
        status: ApptStatus.done,
        note: 'جلسه دوم از شش جلسه',
        createdAt: 2,
      ),
      Appt(
        id: 'a3',
        name: 'مریم احمدی',
        phone: '09359876543',
        service: 'میکاپ',
        dateKey: today.dateKey,
        time: 16 * 60,
        status: ApptStatus.pending,
        createdAt: 3,
      ),
      Appt(
        id: 'a4',
        name: 'الهام رضایی',
        service: 'تزریق بوتاکس',
        dateKey: today.addDays(1).dateKey,
        time: 10 * 60,
        status: ApptStatus.pending,
        createdAt: 4,
      ),
      Appt(
        id: 'a5',
        name: 'نیلوفر جعفری',
        service: 'پاکسازی پوست',
        dateKey: today.addDays(-2).dateKey,
        time: 17 * 60,
        status: ApptStatus.canceled,
        createdAt: 5,
      ),
    ],
  );
  return AppData(store);
}

Future<void> _pumpApp(WidgetTester tester, AppData data) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  await tester.pumpWidget(NobatyarApp(data: data));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('صفحه امروز به‌درستی رندر می‌شود', (tester) async {
    await _pumpApp(tester, _demoData());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home.png'),
    );
  });

  testWidgets('صفحه همه نوبت‌ها به‌درستی رندر می‌شود', (tester) async {
    await _pumpApp(tester, _demoData());
    await tester.tap(find.text('نوبت‌ها'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/appointments.png'),
    );
  });

  testWidgets('صفحه تنظیمات به‌درستی رندر می‌شود', (tester) async {
    await _pumpApp(tester, _demoData());
    await tester.tap(find.text('تنظیمات'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/settings.png'),
    );
  });

  testWidgets('فرم نوبت جدید به‌درستی رندر می‌شود', (tester) async {
    await _pumpApp(tester, _demoData());
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/form.png'),
    );
  });
}
