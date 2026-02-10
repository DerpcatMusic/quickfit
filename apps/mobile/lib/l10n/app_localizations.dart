import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Quickfit'**
  String get appName;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @pageNotFound.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get pageNotFound;

  /// No description provided for @goHome.
  ///
  /// In en, this message translates to:
  /// **'Go Home'**
  String get goHome;

  /// No description provided for @loginTagline.
  ///
  /// In en, this message translates to:
  /// **'Find replacement instructors fast'**
  String get loginTagline;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @continueWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Continue with Email'**
  String get continueWithEmail;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayNameLabel;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get emailInvalid;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLength;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign In'**
  String get alreadyHaveAccount;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign Up'**
  String get dontHaveAccount;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @passwordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent'**
  String get passwordResetSent;

  /// No description provided for @enterEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter your email first'**
  String get enterEmailFirst;

  /// No description provided for @termsPrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our '**
  String get termsPrefix;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get and;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @profileInfo.
  ///
  /// In en, this message translates to:
  /// **'Profile Info'**
  String get profileInfo;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @homeAddress.
  ///
  /// In en, this message translates to:
  /// **'Home Address'**
  String get homeAddress;

  /// No description provided for @addressHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Rothschild 1, Tel Aviv'**
  String get addressHint;

  /// No description provided for @searchRadius.
  ///
  /// In en, this message translates to:
  /// **'Search Radius'**
  String get searchRadius;

  /// No description provided for @maximumDistance.
  ///
  /// In en, this message translates to:
  /// **'Maximum Distance'**
  String get maximumDistance;

  /// No description provided for @expertise.
  ///
  /// In en, this message translates to:
  /// **'Expertise'**
  String get expertise;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdated;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @workRadius.
  ///
  /// In en, this message translates to:
  /// **'Work Radius'**
  String get workRadius;

  /// No description provided for @teachingCategories.
  ///
  /// In en, this message translates to:
  /// **'Teaching Categories'**
  String get teachingCategories;

  /// No description provided for @classTypes.
  ///
  /// In en, this message translates to:
  /// **'Class Types'**
  String get classTypes;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @linkedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Linked Accounts'**
  String get linkedAccounts;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @addPassword.
  ///
  /// In en, this message translates to:
  /// **'Add Password'**
  String get addPassword;

  /// No description provided for @enableEmailLogin.
  ///
  /// In en, this message translates to:
  /// **'Enable email login'**
  String get enableEmailLogin;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @redoOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Redo Onboarding'**
  String get redoOnboarding;

  /// No description provided for @redoOnboardingPrompt.
  ///
  /// In en, this message translates to:
  /// **'This will let you choose your role and profile data again.'**
  String get redoOnboardingPrompt;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @verifiedCredentials.
  ///
  /// In en, this message translates to:
  /// **'Your credentials have been verified'**
  String get verifiedCredentials;

  /// No description provided for @uploadCredentials.
  ///
  /// In en, this message translates to:
  /// **'Upload your certification to get verified'**
  String get uploadCredentials;

  /// No description provided for @notificationsLabelOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get notificationsLabelOff;

  /// No description provided for @notificationsLabelAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notificationsLabelAll;

  /// No description provided for @notificationsLabelSosOnly.
  ///
  /// In en, this message translates to:
  /// **'SOS only'**
  String get notificationsLabelSosOnly;

  /// No description provided for @notificationsLabelRegularOnly.
  ///
  /// In en, this message translates to:
  /// **'Regular only'**
  String get notificationsLabelRegularOnly;

  /// No description provided for @notificationsLabelMuted.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get notificationsLabelMuted;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Alerts'**
  String get notificationsEnable;

  /// No description provided for @notificationsRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular Jobs'**
  String get notificationsRegular;

  /// No description provided for @notificationsSos.
  ///
  /// In en, this message translates to:
  /// **'SOS Jobs'**
  String get notificationsSos;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @languageRestartPrompt.
  ///
  /// In en, this message translates to:
  /// **'Restart app to apply language.'**
  String get languageRestartPrompt;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHebrew.
  ///
  /// In en, this message translates to:
  /// **'עברית'**
  String get languageHebrew;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @filterJobsTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter Jobs'**
  String get filterJobsTitle;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @minimumRateLabelWithValue.
  ///
  /// In en, this message translates to:
  /// **'Minimum Rate: {currency} {value}'**
  String minimumRateLabelWithValue(Object currency, Object value);

  /// No description provided for @currencyILS.
  ///
  /// In en, this message translates to:
  /// **'ILS'**
  String get currencyILS;

  /// No description provided for @currencyAmount.
  ///
  /// In en, this message translates to:
  /// **'{currency} {amount}'**
  String currencyAmount(Object currency, Object amount);

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get applyFilters;

  /// No description provided for @jobClaimedNotification.
  ///
  /// In en, this message translates to:
  /// **'Job claimed! {studioName} will be notified.'**
  String jobClaimedNotification(Object studioName);

  /// No description provided for @availableJobsTitle.
  ///
  /// In en, this message translates to:
  /// **'Available Jobs'**
  String get availableJobsTitle;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @noJobsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No jobs available'**
  String get noJobsAvailable;

  /// No description provided for @noJobsAvailableHint.
  ///
  /// In en, this message translates to:
  /// **'Check back soon or expand your search radius in settings.'**
  String get noJobsAvailableHint;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @urgentJobsTitle.
  ///
  /// In en, this message translates to:
  /// **'Urgent Jobs'**
  String get urgentJobsTitle;

  /// No description provided for @pullToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Pull down to refresh'**
  String get pullToRefresh;

  /// No description provided for @noJobsMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No jobs match your filters'**
  String get noJobsMatchFilters;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear Filters'**
  String get clearFilters;

  /// No description provided for @supportPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Support contact is not configured yet. Add support details in your app settings when ready.'**
  String get supportPlaceholder;

  /// No description provided for @termsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service are not configured yet. Add your terms copy here when ready.'**
  String get termsPlaceholder;

  /// No description provided for @privacyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy is not configured yet. Add your policy copy here when ready.'**
  String get privacyPlaceholder;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Quickfit v{version}'**
  String versionLabel(Object version);

  /// No description provided for @radiusKmLabel.
  ///
  /// In en, this message translates to:
  /// **'{value} km'**
  String radiusKmLabel(Object value);

  /// No description provided for @zonesSelectedLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} zones selected'**
  String zonesSelectedLabel(Object count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'he':
      return AppLocalizationsHe();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
