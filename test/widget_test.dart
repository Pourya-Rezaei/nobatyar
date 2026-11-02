import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nobatyar/core/jalali.dart';
import 'package:nobatyar/data/app_data.dart';
import 'package:nobatyar/data/models.dart';
import 'package:nobatyar/data/storage.dart';
import 'package:nobatyar/main.dart';

/// بارگذاری فونت واقعی وزیرمتن و آیکون‌های متریال برای رندر درست در تست
Future<void> _loadFonts() async {
  const weights = ['Regular', 'Medium', 'SemiBold', 'Bold'];
  for (final w in weights) {
    final bytes = File('assets/fonts/Vazirmatn-$w.ttf').readAsBytesSync();
    final loader = FontLoader('Vazirmatn')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }

  final iconFont = File('test/fonts/MaterialIcons-Regular.otf');
  assert(iconFont.existsSync(),
      'test/fonts/MaterialIcons-Regular.otf not found — icons would render as tofu squares');
  final iconBytes = iconFont.readAsBytesSync();
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(iconBytes.buffer)));
  await iconLoader.load();
}

AppData _demoData({AppThemeMode themeMode = AppThemeMode.dark}) {
  final today = todayJalali();
  final store = MemoryStore(
    settings: BizSettings(
      name: 'کلینیک زیبایی رز',
      type: BusinessType.beautyClinic,
      themeMode: themeMode,
      services: [
        const Service(name: 'پاکسازی پوست', price: 450000),
        const Service(name: 'لیزر موهای زائد', price: 800000),
        const Service(name: 'میکاپ', price: 2500000),
        const Service(name: 'تزریق بوتاکس', price: 3500000),
      ],
      blocks: [
        TimeBlock(
          id: 'blk1',
          weekDay: 4, // پنجشنبه‌ها استراحت ناهار
          start: 13 * 60,
          end: 14 * 60,
        ),
      ],
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
        price: 450000,
        createdAt: 1,
      ),
      Appt(
        id: 'a2',
        name: 'نگار کریمی',
        service: 'لیزر موهای زائد',
        dateKey: today.dateKey,
        time: 11 * 60,
        status: ApptStatus.done,
        price: 800000,
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
        price: 2500000,
        createdAt: 3,
      ),
      Appt(
        id: 'a4',
        name: 'سارا محمدی',
        phone: '09121234567',
        service: 'پاکسازی پوست',
        dateKey: today.addDays(-14).dateKey,
        time: 10 * 60,
        status: ApptStatus.done,
        price: 450000,
        createdAt: 4,
      ),
      Appt(
        id: 'a5',
        name: 'الهام رضایی',
        service: 'تزریق بوتاکس',
        dateKey: today.addDays(1).dateKey,
        time: 10 * 60,
        status: ApptStatus.pending,
        createdAt: 5,
      ),
      Appt(
        id: 'a6',
        name: 'نیلوفر جعفری',
        service: 'پاکسازی پوست',
        dateKey: today.addDays(-2).dateKey,
        time: 17 * 60,
        status: ApptStatus.canceled,
        createdAt: 6,
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

  testWidgets('صفحه امروز (تم تیره) به‌درستی رندر می‌شود', (tester) async {
    await _pumpApp(tester, _demoData());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home.png'),
    );
  });

  testWidgets('صفحه امروز (تم روشن) به‌درستی رندر می‌شود', (tester) async {
    await _pumpApp(tester, _demoData(themeMode: AppThemeMode.light));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_light.png'),
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

  testWidgets('صفحه مشتریان به‌درستی رندر می‌شود', (tester) async {
    await _pumpApp(tester, _demoData());
    await tester.tap(find.text('مشتریان'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/customers.png'),
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

  testWidgets('صفحه آمار به‌درستی رندر می‌شود', (tester) async {
    await _pumpApp(tester, _demoData());
    await tester.tap(find.text('نوبت‌ها'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('آمار و نمودارها'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/stats.png'),
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
