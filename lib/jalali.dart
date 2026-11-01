/// تبدیل تاریخ شمسی ↔ میلادی بر پایه الگوریتم متن‌باز jalaali-js
/// به‌همراه ابزار نمایش تاریخ و اعداد فارسی
library;

const List<String> kJalaliMonths = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];

const List<String> kWeekDays = [
  'شنبه',
  'یکشنبه',
  'دوشنبه',
  'سه‌شنبه',
  'چهارشنبه',
  'پنجشنبه',
  'جمعه',
];

const List<String> kWeekDaysShort = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

const String _faDigitChars = '۰۱۲۳۴۵۶۷۸۹';

/// تبدیل ارقام لاتین به فارسی: «1405» → «۱۴۰۵»
String faDigits(String input) => input.replaceAllMapped(
      RegExp(r'[0-9]'),
      (m) => _faDigitChars[int.parse(m.group(0)!)],
    );

/// تبدیل ارقام فارسی به لاتین (برای جستجو و مقایسه)
String enDigits(String input) => input.replaceAllMapped(
      RegExp(r'[۰-۹]'),
      (m) => '${_faDigitChars.indexOf(m.group(0)!)}',
    );

String faNum(num n) => faDigits(n.toString());

/// نمایش دقیقه از نیمه‌شب به شکل «۰۹:۳۰»
String faTime(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return faDigits('$h:$m');
}

/// یک تاریخ شمسی
class Jalali implements Comparable<Jalali> {
  final int year;
  final int month; // ۱ تا ۱۲
  final int day; // ۱ تا ۳۱

  const Jalali(this.year, this.month, this.day);

  /// کلید عددی یکتا: ۱۴۰۵۰۸۰۹
  int get dateKey => year * 10000 + month * 100 + day;

  static Jalali fromKey(int key) =>
      Jalali(key ~/ 10000, (key % 10000) ~/ 100, key % 100);

  /// شماره روز هفته: ۰ = شنبه … ۶ = جمعه
  int get weekDay => (jdn % 7 + 2) % 7;

  /// شماره روز در سال
  int get dayOfYear {
    var sum = 0;
    for (var m = 1; m < month; m++) {
      sum += jalaliMonthLength(year, m);
    }
    return sum + day;
  }

  /// شماره روز ژولینی (برای مرتب‌سازی و محاسبات)
  int get jdn => _j2d(year, month, day);

  String get monthName => kJalaliMonths[month - 1];
  String get weekDayName => kWeekDays[weekDay];

  /// «۹ آبان ۱۴۰۵»
  String get fullText => '${faNum(day)} $monthName ${faNum(year)}';

  /// «۱۴۰۵/۰۸/۰۹»
  String get shortText => faDigits(
      '${year.toString().padLeft(4, '0')}/${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}');

  Jalali addDays(int days) =>
      jalaliFromDateTime(toDateTime().add(Duration(days: days)));

  DateTime toDateTime() {
    final g = _d2g(_j2d(year, month, day));
    return DateTime(g[0], g[1], g[2]);
  }

  bool isBefore(Jalali other) => jdn < other.jdn;
  bool isAfter(Jalali other) => jdn > other.jdn;

  @override
  int compareTo(Jalali other) => jdn.compareTo(other.jdn);

  @override
  bool operator ==(Object other) =>
      other is Jalali && other.dateKey == dateKey;

  @override
  int get hashCode => dateKey;

  @override
  String toString() => shortText;
}

Jalali todayJalali() => jalaliFromDateTime(DateTime.now());

Jalali jalaliFromDateTime(DateTime dt) => _d2j(_g2d(dt.year, dt.month, dt.day));

/// طول ماه شمسی
int jalaliMonthLength(int jy, int jm) {
  if (jm <= 6) return 31;
  if (jm <= 11) return 30;
  return isJalaliLeap(jy) ? 30 : 29;
}

/// آیا سال شمسی کبیسه است؟
/// (در الگوریتم jalaali مقدار leap==0 به معنای کبیسه بودن خود سال است و
/// leap==1 یعنی سال قبل کبیسه بوده — این را با سال‌های کبیسه واقعی
/// ۱۳۷۵، ۱۳۷۹، …، ۱۴۰۳، ۱۴۰۸ راستی‌آزمایی کرده‌ایم)
bool isJalaliLeap(int jy) => _jalCal(jy)[0] == 0;

/// برچسب نسبی روز: امروز / فردا / دیروز
String relativeDayLabel(Jalali j, Jalali today) {
  final diff = j.jdn - today.jdn;
  if (diff == 0) return 'امروز';
  if (diff == 1) return 'فردا';
  if (diff == -1) return 'دیروز';
  return '';
}

// ---------------------------------------------------------------------------
// الگوریتم تبدیل (port کامل jalaali-js)
// ---------------------------------------------------------------------------

int _div(int a, int b) => a ~/ b;
int _mod(int a, int b) => a % b;

const List<int> _breaks = [
  -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210, 1635,
  2060, 2097, 2192, 2262, 2324, 2394, 2456, 3178,
];

/// خروجی: [leap, gy, march]
List<int> _jalCal(int jy) {
  final gy = jy + 621;
  var leapJ = -14;
  var jp = _breaks[0];
  var jm = 0;
  var jump = 0;
  var leap = 0;
  var march = 0;
  var n = 0;

  for (var i = 1; i < _breaks.length; i++) {
    jm = _breaks[i];
    jump = jm - jp;
    if (jy < jm) break;
    leapJ += _div(jump, 33) * 8 + _div(_mod(jump, 33), 4);
    jp = jm;
  }
  n = jy - jp;

  leapJ += _div(n, 33) * 8 + _div(_mod(n, 33) + 3, 4);
  if (_mod(jump, 33) == 4 && jump - n == 4) leapJ += 1;

  final leapG = _div(gy, 4) - _div((_div(gy, 100) + 1) * 3, 4) - 150;
  march = 20 + leapJ - leapG;

  if (jump - n < 6) n = n - jump + _div(jump + 4, 33) * 33;
  leap = _mod(_mod(n + 1, 33) - 1, 4);
  if (leap == -1) leap = 4;

  return [leap, gy, march];
}

int _j2d(int jy, int jm, int jd) {
  final r = _jalCal(jy);
  return _g2d(r[1], 3, r[2]) + (jm - 1) * 31 - _div(jm, 7) * (jm - 7) + jd - 1;
}

Jalali _d2j(int jdn) {
  final g = _d2g(jdn);
  var jy = g[0] - 621;
  final r = _jalCal(jy);
  final jdn1f = _g2d(g[0], 3, r[2]);
  var k = jdn - jdn1f;
  if (k >= 0) {
    if (k <= 185) {
      return Jalali(jy, 1 + _div(k, 31), _mod(k, 31) + 1);
    }
    k -= 186;
  } else {
    jy -= 1;
    k += 179;
    if (r[0] == 1) k += 1;
  }
  return Jalali(jy, 7 + _div(k, 30), _mod(k, 30) + 1);
}

int _g2d(int gy, int gm, int gd) {
  var d = _div((gy + _div(gm - 8, 6) + 100100) * 1461, 4) +
      _div(153 * _mod(gm + 9, 12) + 2, 5) +
      gd -
      34840408;
  d = d - _div(_div(gy + 100100 + _div(gm - 8, 6), 100) * 3, 4) + 752;
  return d;
}

List<int> _d2g(int jdn) {
  var j = 4 * jdn + 139361631;
  j = j + _div(_div(4 * jdn + 183187720, 146097) * 3, 4) * 4 - 3908;
  final i = _div(_mod(j, 1461), 4) * 5 + 308;
  final gd = _div(_mod(i, 153), 5) + 1;
  final gm = _mod(_div(i, 153), 12) + 1;
  final gy = _div(j, 1461) - 100100 + _div(8 - gm, 6);
  return [gy, gm, gd];
}
