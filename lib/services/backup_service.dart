import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// خطای پشتیبان با پیام فارسی مناسب نمایش به کاربر.
class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

/// سرویس پشتیبان‌گیری: اعتبارسنجی ساختاری + رمزنگاری فایل.
///
/// دو فرمت خروجی:
///  - **ساده**: فایل JSON خوانا (سازگار با نسخه‌های قبل)
///  - **رمزدار**: ظرف باینری `NBK1` با AES-256-GCM و کلید
///    مشتقشده از رمز با PBKDF2-HMAC-SHA256
///
/// ساختار ظرف رمزدار:
/// ```
/// "NBK1" | uint32 lenHeader | هدر JSON (utf8) | متن رمزشده
/// هدر: {v, kdf, iter, salt, nonce, mac}
/// ```
class BackupService {
  BackupService._();

  /// شناسهٔ چهاربایتی ابتدای فایل رمزدار
  static const String containerMagic = 'NBK1';

  /// تعداد تکرار PBKDF2 — تعادل امنیت و سرعت روی موبایل
  static const int kdfIterations = 150000;

  static const int _maxAppts = 50000;
  static const int _maxServices = 100;
  static const int _maxBlocks = 200;

  // -----------------------------------------------------------------
  // ساخت خروجی

  /// خروجی سادهٔ JSON (خوانا — مثل نسخه‌های قبل)
  static String encodePlain(Map<String, dynamic> backup) =>
      const JsonEncoder.withIndent('  ').convert(backup);

  /// خروجی رمزنگاری‌شدهٔ AES-256-GCM با رمز کاربر
  static Future<Uint8List> encodeEncrypted(
    Map<String, dynamic> backup,
    String password,
  ) async {
    final salt = newSalt();
    final nonce = newNonce();

    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: kdfIterations,
      bits: 256,
    );
    final key = await kdf.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );

    final clearText = utf8.encode(jsonEncode(backup));
    final box = await AesGcm.with256bits().encrypt(
      clearText,
      secretKey: key,
      nonce: nonce,
    );

    final header = jsonEncode({
      'v': 1,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iter': kdfIterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'mac': base64Encode(box.mac.bytes),
    });

    final headerBytes = utf8.encode(header);
    final out = BytesBuilder();
    out.add(utf8.encode(containerMagic));
    out.add(_uint32(headerBytes.length));
    out.add(headerBytes);
    out.add(box.cipherText);
    return out.toBytes();
  }

  // -----------------------------------------------------------------
  // خواندن و تشخیص فرمت

  /// آیا این فایل پشتیبانِ رمزدار است؟
  static bool isEncrypted(Uint8List bytes) {
    if (bytes.length < 4) return false;
    return String.fromCharCodes(bytes.take(4)) == containerMagic;
  }

  /// خواندن فایل پشتیبان (ساده یا رمزدار) + اعتبارسنجی کامل.
  /// برای فایل رمزدار، [password] الزامی است.
  static Future<Map<String, dynamic>> readBackup(
    Uint8List bytes,
    String? password,
  ) async {
    if (isEncrypted(bytes)) {
      if (password == null || password.isEmpty) {
        throw const BackupException('این پشتیبان با رمز محافظت می‌شود — رمز را وارد کن.');
      }
      final map = await _decryptContainer(bytes, password);
      return validateBackup(map);
    }
    // فایل سادهٔ JSON
    final map = _tryJsonDecode(bytes);
    if (map == null) {
      throw const BackupException('این فایل پشتیبان نوبت‌یار نیست.');
    }
    return validateBackup(map);
  }

  static Future<Map<String, dynamic>> _decryptContainer(
    Uint8List bytes,
    String password,
  ) async {
    try {
      final data = ByteData.sublistView(bytes);
      if (bytes.length < 8) throw const FormatException();
      final headerLen = data.getUint32(4);
      if (headerLen <= 0 || 8 + headerLen >= bytes.length) {
        throw const FormatException();
      }
      final headerJson =
          utf8.decode(bytes.sublist(8, 8 + headerLen), allowMalformed: false);
      final header = jsonDecode(headerJson);
      if (header is! Map<String, dynamic>) throw const FormatException();

      final kdf = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: (header['iter'] as num?)?.toInt() ?? kdfIterations,
        bits: 256,
      );
      final key = await kdf.deriveKeyFromPassword(
        password: password,
        nonce: base64Decode(header['salt'] as String),
      );

      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(
          bytes.sublist(8 + headerLen),
          nonce: base64Decode(header['nonce'] as String),
          mac: Mac(base64Decode(header['mac'] as String)),
        ),
        secretKey: key,
      );
      return _tryJsonDecode(Uint8List.fromList(clear)) ??
          (throw const FormatException());
    } on BackupException {
      rethrow;
    } on SecretBoxAuthenticationError {
      throw const BackupException('رمز پشتیبان درست نیست.');
    } catch (_) {
      throw const BackupException('فایل رمزدار خراب است یا ساخته‌شدهٔ نوبت‌یار نیست.');
    }
  }

  static Map<String, dynamic>? _tryJsonDecode(Uint8List bytes) {
    try {
      // حذف BOM احتمالی و فضای خالی ابتدای فایل
      var s = utf8.decode(bytes, allowMalformed: false);
      if (s.startsWith('﻿')) s = s.substring(1);
      final j = jsonDecode(s.trimLeft());
      return j is Map<String, dynamic> ? j : null;
    } catch (_) {
      return null;
    }
  }

  // -----------------------------------------------------------------
  // اعتبارسنجی ساختاری — پیش از اعمال روی داده‌های واقعی

  /// اعتبارسنجی عمیق ساختار پشتیبان؛ خروجی همان نقشهٔ تاییدشده است.
  /// در صورت مشکل [BackupException] با پیام فارسی پرتاب می‌شود.
  static Map<String, dynamic> validateBackup(Map<String, dynamic> j) {
    if (j['app'] != 'nobatyar') {
      throw const BackupException('این فایل پشتیبان نوبت‌یار نیست.');
    }
    final format = j['format'];
    if (format is! int || format < 1 || format > 2) {
      throw const BackupException('نسخهٔ فایل پشتیبان پشتیبانی نمی‌شود.');
    }
    final rawAppts = j['appointments'];
    if (rawAppts is! List) {
      throw const BackupException('ساختار فایل پشتیبان معتبر نیست.');
    }
    if (rawAppts.length > _maxAppts) {
      throw const BackupException('تعداد نوبت‌های این پشتیبان غیرمعقول است.');
    }
    for (var i = 0; i < rawAppts.length; i++) {
      _validateAppt(rawAppts[i], i);
    }
    final rawSettings = j['settings'];
    if (rawSettings is! Map<String, dynamic>) {
      throw const BackupException('ساختار فایل پشتیبان معتبر نیست.');
    }
    _validateSettings(rawSettings);
    return j;
  }

  static void _validateAppt(dynamic e, int index) {
    final label = 'نوبت شماره ${index + 1}';
    if (e is! Map) {
      throw BackupException('$label ساختار نامعتبر دارد.');
    }
    final id = e['id'];
    if (id is! String || id.isEmpty || id.length > 64) {
      throw BackupException('$label شناسهٔ نامعتبر دارد.');
    }
    _checkStr(e['name'], '$label نام نامعتبر دارد.', 100);
    _checkStr(e['phone'], '$label شماره تماس نامعتبر دارد.', 24);
    _checkStr(e['service'], '$label نام خدمت نامعتبر دارد.', 100);
    _checkStr(e['note'], '$label یادداشت نامعتبر دارد.', 1000);

    final dateKey = e['dateKey'];
    if (dateKey is! int || dateKey < 13000101 || dateKey > 14991231) {
      throw BackupException('$label تاریخ نامعتبر دارد.');
    }
    if (dateKey % 10000 ~/ 100 < 1 || dateKey % 10000 ~/ 100 > 12 ||
        dateKey % 100 < 1 || dateKey % 100 > 31) {
      throw BackupException('$label تاریخ نامعتبر دارد.');
    }
    final time = e['time'];
    if (time is! int || time < 0 || time > 24 * 60) {
      throw BackupException('$label ساعت نامعتبر دارد.');
    }
    final price = e['price'];
    if (price != null &&
        (price is! int || price < 0 || price > 1000000000000)) {
      throw BackupException('$label مبلغ نامعتبر دارد.');
    }
    final status = e['status'];
    if (status is String &&
        const {'pending', 'confirmed', 'done', 'canceled'}
            .contains(status) == false) {
      throw BackupException('$label وضعیت نامعتبر دارد.');
    }
  }

  static void _validateSettings(Map<String, dynamic> s) {
    _checkStr(s['name'], 'نام کسب‌وکار در پشتیبان نامعتبر است.', 100);
    _checkRange(s['dayStart'], 'ساعت شروع کار', 0, 24 * 60);
    _checkRange(s['dayEnd'], 'ساعت پایان کار', 0, 24 * 60);
    _checkRange(s['slot'], 'مدت هر نوبت', 5, 240);
    _checkRange(s['reminderLead'], 'فاصلهٔ یادآوری', 0, 24 * 60);
    _checkRange(s['morningHour'], 'ساعت خلاصهٔ صبحگاهی', 0, 24 * 60);

    final services = s['services'];
    if (services is! List || services.length > _maxServices) {
      throw const BackupException('فهرست خدمات در پشتیبان نامعتبر است.');
    }
    for (final sv in services) {
      if (sv is! Map) {
        throw const BackupException('فهرست خدمات در پشتیبان نامعتبر است.');
      }
      _checkStr(sv['name'], 'نام خدمت در پشتیبان نامعتبر است.', 100);
      final p = sv['price'];
      if (p != null && (p is! int || p < 0 || p > 1000000000000)) {
        throw const BackupException('قیمت خدمت در پشتیبان نامعتبر است.');
      }
    }
    final blocks = s['blocks'];
    if (blocks is! List || blocks.length > _maxBlocks) {
      throw const BackupException('بازه‌های غیرفعال در پشتیبان نامعتبر است.');
    }
    for (final b in blocks) {
      if (b is! Map) {
        throw const BackupException('بازه‌های غیرفعال در پشتیبان نامعتبر است.');
      }
      _checkRange(b['start'], 'ساعت شروع بازهٔ غیرفعال', 0, 24 * 60);
      _checkRange(b['end'], 'ساعت پایان بازهٔ غیرفعال', 0, 24 * 60);
      final dk = b['dateKey'];
      if (dk != null && (dk is! int || dk < 13000101 || dk > 14991231)) {
        throw const BackupException('تاریخ تعطیلی در پشتیبان نامعتبر است.');
      }
      final wd = b['weekDay'];
      if (wd != null && (wd is! int || wd < 0 || wd > 6)) {
        throw const BackupException('روز هفتهٔ بازهٔ غیرفعال نامعتبر است.');
      }
    }
  }

  static void _checkStr(dynamic v, String err, int maxLen) {
    if (v is String && (v.length > maxLen)) throw BackupException(err);
    if (v != null && v is! String) throw BackupException(err);
  }

  static void _checkRange(dynamic v, String label, int min, int max) {
    if (v == null) return;
    if (v is! int || v < min || v > max) {
      throw BackupException('$label در پشتیبان نامعتبر است.');
    }
  }

  // -----------------------------------------------------------------
  // پرتصادفی بودن قوی برای salt و nonce

  /// مولد اعداد تصادفی رمزنگارانهٔ سیستم عامل
  static final Random _rng = Random.secure();

  /// نمک تصادفی ۱۶ بایتی
  static Uint8List newSalt() => _randomBytes(16);

  /// nonce تصادفی ۱۲ بایتی استاندارد GCM
  static Uint8List newNonce() => _randomBytes(12);

  static Uint8List _randomBytes(int n) {
    final b = Uint8List(n);
    for (var i = 0; i < n; i++) {
      b[i] = _rng.nextInt(256);
    }
    return b;
  }

  static Uint8List _uint32(int v) =>
      (ByteData(4)..setUint32(0, v)).buffer.asUint8List();
}
