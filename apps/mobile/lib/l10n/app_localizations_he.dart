// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appName => 'Quickfit';

  @override
  String get loading => 'טוען...';

  @override
  String get pageNotFound => 'העמוד לא נמצא';

  @override
  String get goHome => 'לדף הבית';

  @override
  String get loginTagline => 'מצא מחליפי מדריכים מהר';

  @override
  String get continueWithGoogle => 'המשך עם Google';

  @override
  String get continueWithApple => 'המשך עם Apple';

  @override
  String get continueWithEmail => 'המשך עם אימייל';

  @override
  String get or => 'או';

  @override
  String get back => 'חזרה';

  @override
  String get createAccount => 'יצירת חשבון';

  @override
  String get signIn => 'התחברות';

  @override
  String get nameLabel => 'שם';

  @override
  String get displayNameLabel => 'שם תצוגה';

  @override
  String get emailLabel => 'אימייל';

  @override
  String get passwordLabel => 'סיסמה';

  @override
  String get emailRequired => 'נדרש אימייל';

  @override
  String get emailInvalid => 'הזן אימייל תקין';

  @override
  String get passwordRequired => 'נדרשת סיסמה';

  @override
  String get passwordMinLength => 'סיסמה חייבת להיות לפחות 6 תווים';

  @override
  String get alreadyHaveAccount => 'כבר יש לך חשבון? התחבר';

  @override
  String get dontHaveAccount => 'אין לך חשבון? הירשם';

  @override
  String get forgotPassword => 'שכחת סיסמה?';

  @override
  String get passwordResetSent => 'נשלחה הודעת איפוס סיסמה';

  @override
  String get enterEmailFirst => 'הכנס אימייל קודם';

  @override
  String get termsPrefix => 'בהמשך, אתה מסכים ל';

  @override
  String get and => 'ו';

  @override
  String get termsOfService => 'תנאי שימוש';

  @override
  String get privacyPolicy => 'מדיניות פרטיות';

  @override
  String get profileInfo => 'פרטי פרופיל';

  @override
  String get phoneNumber => 'מספר טלפון';

  @override
  String get homeAddress => 'כתובת בית';

  @override
  String get addressHint => 'לדוגמה: רוטשילד 1, תל אביב';

  @override
  String get searchRadius => 'רדיוס חיפוש';

  @override
  String get maximumDistance => 'מרחק מקסימלי';

  @override
  String get expertise => 'התמחות';

  @override
  String get saveChanges => 'שמירת שינויים';

  @override
  String get profileUpdated => 'הפרופיל עודכן בהצלחה';

  @override
  String get account => 'חשבון';

  @override
  String get notSet => 'לא הוגדר';

  @override
  String get email => 'אימייל';

  @override
  String get workRadius => 'רדיוס עבודה';

  @override
  String get teachingCategories => 'קטגוריות הוראה';

  @override
  String get classTypes => 'סוגי שיעורים';

  @override
  String get settings => 'הגדרות';

  @override
  String get linkedAccounts => 'חשבונות מקושרים';

  @override
  String get none => 'אין';

  @override
  String get addPassword => 'הוסף סיסמה';

  @override
  String get enableEmailLogin => 'אפשר התחברות באימייל';

  @override
  String get notifications => 'התראות';

  @override
  String get redoOnboarding => 'בצע מחדש את ההרשמה';

  @override
  String get redoOnboardingPrompt => 'זה יאפשר לבחור תפקיד ופרטי פרופיל מחדש.';

  @override
  String get redo => 'בצע מחדש';

  @override
  String get cancel => 'ביטול';

  @override
  String get language => 'שפה';

  @override
  String get helpSupport => 'עזרה ותמיכה';

  @override
  String get signOut => 'התנתקות';

  @override
  String get verify => 'אימות';

  @override
  String get verifiedCredentials => 'המסמכים שלך אומתו';

  @override
  String get uploadCredentials => 'העלה תעודה כדי לקבל אימות';

  @override
  String get notificationsLabelOff => 'כבוי';

  @override
  String get notificationsLabelAll => 'הכל';

  @override
  String get notificationsLabelSosOnly => 'רק SOS';

  @override
  String get notificationsLabelRegularOnly => 'רק רגיל';

  @override
  String get notificationsLabelMuted => 'מושתק';

  @override
  String get notificationsTitle => 'התראות';

  @override
  String get notificationsEnable => 'אפשר התראות';

  @override
  String get notificationsRegular => 'עבודות רגילות';

  @override
  String get notificationsSos => 'עבודות SOS';

  @override
  String get save => 'שמור';

  @override
  String get languageRestartPrompt =>
      'יש להפעיל מחדש את האפליקציה כדי להחיל את השפה.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHebrew => 'עברית';

  @override
  String get close => 'סגור';

  @override
  String get editProfile => 'עריכת פרופיל';

  @override
  String get filterJobsTitle => 'סינון עבודות';

  @override
  String get reset => 'איפוס';

  @override
  String get categoryLabel => 'קטגוריה';

  @override
  String minimumRateLabelWithValue(Object currency, Object value) {
    return 'תעריף מינימלי: $currency $value';
  }

  @override
  String get currencyILS => 'ש\"ח';

  @override
  String currencyAmount(Object currency, Object amount) {
    return '$currency $amount';
  }

  @override
  String get applyFilters => 'החל סינונים';

  @override
  String jobClaimedNotification(Object studioName) {
    return 'העבודה נתפסה! הסטודיו $studioName יקבל הודעה.';
  }

  @override
  String get availableJobsTitle => 'עבודות זמינות';

  @override
  String get somethingWentWrong => 'אירעה שגיאה';

  @override
  String get tryAgain => 'נסה שוב';

  @override
  String get noJobsAvailable => 'אין עבודות זמינות';

  @override
  String get noJobsAvailableHint =>
      'בדוק שוב בקרוב או הרחב את רדיוס החיפוש בהגדרות.';

  @override
  String get refresh => 'רענן';

  @override
  String get urgentJobsTitle => 'עבודות דחופות';

  @override
  String get pullToRefresh => 'משוך למטה כדי לרענן';

  @override
  String get noJobsMatchFilters => 'אין עבודות שמתאימות לסינונים שלך';

  @override
  String get clearFilters => 'נקה סינונים';

  @override
  String get supportPlaceholder =>
      'פרטי תמיכה עדיין לא הוגדרו. הוסף אותם בהגדרות כשיהיה מוכן.';

  @override
  String get termsPlaceholder =>
      'תנאי השימוש עדיין לא הוגדרו. הוסף כאן את הטקסט כשיהיה מוכן.';

  @override
  String get privacyPlaceholder =>
      'מדיניות הפרטיות עדיין לא הוגדרה. הוסף כאן את הטקסט כשיהיה מוכן.';

  @override
  String versionLabel(Object version) {
    return 'Quickfit v$version';
  }

  @override
  String radiusKmLabel(Object value) {
    return '$value ק\"מ';
  }

  @override
  String zonesSelectedLabel(Object count) {
    return '$count אזורים נבחרו';
  }
}
