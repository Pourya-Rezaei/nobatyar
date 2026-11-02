/// نسخهٔ فعلی اپ — باید با `version` در pubspec.yaml یکی باشد.
///
/// تست `v121_test.dart` این تناسب را چک می‌کند تا اگر نسخه بالا رفت و
/// این ثابت فراموش شد، CI قرمز شود.
const String appVersion = '1.2.1';

/// ریپوی رسمی — مبدا بررسی به‌روزرسانی و مقصد لینک دانلود
const String repoOwner = 'Pourya-Rezaei';
const String repoName = 'nobatyar';

/// آدرس صفحهٔ ریلیزها (برای دکمهٔ دانلود نسخهٔ جدید)
const String releasesUrl = 'https://github.com/$repoOwner/$repoName/releases';

/// آدرس API آخرین ریلیز
const String latestReleaseApiUrl =
    'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

/// شمارهٔ ساخت — فقط برای نمایش در تنظیمات
const String buildNumber = '4';
