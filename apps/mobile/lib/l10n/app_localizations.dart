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

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

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

  /// No description provided for @changeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change Email'**
  String get changeEmail;

  /// No description provided for @newEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'New Email'**
  String get newEmailLabel;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPasswordLabel;

  /// No description provided for @currentPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Current password is required'**
  String get currentPasswordRequired;

  /// No description provided for @emailUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Please enter a different email'**
  String get emailUnchanged;

  /// No description provided for @sendVerification.
  ///
  /// In en, this message translates to:
  /// **'Send Verification'**
  String get sendVerification;

  /// No description provided for @emailChangeVerificationSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent. Confirm it to complete your email change.'**
  String get emailChangeVerificationSent;

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

  /// No description provided for @sosLabel.
  ///
  /// In en, this message translates to:
  /// **'SOS'**
  String get sosLabel;

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

  /// No description provided for @profileRoleStudio.
  ///
  /// In en, this message translates to:
  /// **'Studio'**
  String get profileRoleStudio;

  /// No description provided for @profileRoleInstructor.
  ///
  /// In en, this message translates to:
  /// **'Instructor'**
  String get profileRoleInstructor;

  /// No description provided for @profileAnonymousUser.
  ///
  /// In en, this message translates to:
  /// **'Anonymous User'**
  String get profileAnonymousUser;

  /// No description provided for @profileProviderGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get profileProviderGoogle;

  /// No description provided for @profileProviderApple.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get profileProviderApple;

  /// No description provided for @profileProviderEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileProviderEmail;

  /// No description provided for @profileProviderOauth.
  ///
  /// In en, this message translates to:
  /// **'OAuth'**
  String get profileProviderOauth;

  /// No description provided for @profileEmailManagedByProvider.
  ///
  /// In en, this message translates to:
  /// **'Email is managed by {providersLabel} and cannot be edited directly in the app yet.'**
  String profileEmailManagedByProvider(Object providersLabel);

  /// No description provided for @profileEmailManagedByProviderWithFallback.
  ///
  /// In en, this message translates to:
  /// **'Email is managed by {providersLabel} and cannot be edited directly in the app yet. You can also add password login as a fallback.'**
  String profileEmailManagedByProviderWithFallback(Object providersLabel);

  /// No description provided for @profileDisplayNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Display name is required'**
  String get profileDisplayNameRequired;

  /// No description provided for @profileVerifiedInstructor.
  ///
  /// In en, this message translates to:
  /// **'Verified Instructor'**
  String get profileVerifiedInstructor;

  /// No description provided for @profileAddPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Add a password to allow signing in with email ({email})'**
  String profileAddPasswordDescription(Object email);

  /// No description provided for @profilePasswordPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Password (6+ chars)'**
  String get profilePasswordPlaceholder;

  /// No description provided for @profilePasswordAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password added! You can now sign in with email.'**
  String get profilePasswordAddedSuccess;

  /// No description provided for @profilePasswordAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add password'**
  String get profilePasswordAddFailed;

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

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// No description provided for @syncedAt.
  ///
  /// In en, this message translates to:
  /// **'Synced {time}'**
  String syncedAt(Object time);

  /// No description provided for @noJobsInThreeDayWindow.
  ///
  /// In en, this message translates to:
  /// **'No jobs in this 3-day window.'**
  String get noJobsInThreeDayWindow;

  /// No description provided for @scheduleHoursCompact.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String scheduleHoursCompact(Object hours);

  /// No description provided for @scheduleGoogleCalendarDetailsHeader.
  ///
  /// In en, this message translates to:
  /// **'QuickFit job #{jobId}'**
  String scheduleGoogleCalendarDetailsHeader(Object jobId);

  /// No description provided for @scheduleGoogleCalendarDetailsStudio.
  ///
  /// In en, this message translates to:
  /// **'Studio: {studioName}'**
  String scheduleGoogleCalendarDetailsStudio(Object studioName);

  /// No description provided for @instructorMapServiceArea.
  ///
  /// In en, this message translates to:
  /// **'Service Area'**
  String get instructorMapServiceArea;

  /// No description provided for @instructorMapLiveJobsInView.
  ///
  /// In en, this message translates to:
  /// **'{count} live jobs in view'**
  String instructorMapLiveJobsInView(Object count);

  /// No description provided for @instructorMapTapToDropPin.
  ///
  /// In en, this message translates to:
  /// **'Tap the map once to drop your pin.'**
  String get instructorMapTapToDropPin;

  /// No description provided for @instructorMapPinUpdatedTapSave.
  ///
  /// In en, this message translates to:
  /// **'Pin updated. Tap Save Changes to apply.'**
  String get instructorMapPinUpdatedTapSave;

  /// No description provided for @instructorMapTypeAddressToMovePin.
  ///
  /// In en, this message translates to:
  /// **'Type address to move pin'**
  String get instructorMapTypeAddressToMovePin;

  /// No description provided for @instructorMapAddressNotFound.
  ///
  /// In en, this message translates to:
  /// **'Address not found. Try a more specific address.'**
  String get instructorMapAddressNotFound;

  /// No description provided for @instructorMapPleaseSelectLocation.
  ///
  /// In en, this message translates to:
  /// **'Please select a location on the map'**
  String get instructorMapPleaseSelectLocation;

  /// No description provided for @instructorMapPleaseSelectOneZone.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one zone'**
  String get instructorMapPleaseSelectOneZone;

  /// No description provided for @instructorMapSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully'**
  String get instructorMapSettingsSaved;

  /// No description provided for @instructorMapErrorSavingSettings.
  ///
  /// In en, this message translates to:
  /// **'Error saving settings: {error}'**
  String instructorMapErrorSavingSettings(Object error);

  /// No description provided for @instructorMapMapSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Map settings'**
  String get instructorMapMapSettingsTooltip;

  /// No description provided for @instructorMapDropPinTooltip.
  ///
  /// In en, this message translates to:
  /// **'Drop pin'**
  String get instructorMapDropPinTooltip;

  /// No description provided for @instructorMapApplyAddressTooltip.
  ///
  /// In en, this message translates to:
  /// **'Apply address'**
  String get instructorMapApplyAddressTooltip;

  /// No description provided for @mapSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Map Settings'**
  String get mapSettingsTitle;

  /// No description provided for @mapSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust how and where job matches are discovered.'**
  String get mapSettingsSubtitle;

  /// No description provided for @mapModeRadius.
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get mapModeRadius;

  /// No description provided for @mapModeZones.
  ///
  /// In en, this message translates to:
  /// **'Zones'**
  String get mapModeZones;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @mapSearchRadius.
  ///
  /// In en, this message translates to:
  /// **'Search Radius'**
  String get mapSearchRadius;

  /// No description provided for @mapSelectedZones.
  ///
  /// In en, this message translates to:
  /// **'Selected Zones'**
  String get mapSelectedZones;

  /// No description provided for @mapActiveCount.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String mapActiveCount(Object count);

  /// No description provided for @mapZoneSelectionHint.
  ///
  /// In en, this message translates to:
  /// **'Zone selection is done directly on the map. Close this sheet to edit zones.'**
  String get mapZoneSelectionHint;

  /// No description provided for @mapLoadingZones.
  ///
  /// In en, this message translates to:
  /// **'Loading zones...'**
  String get mapLoadingZones;

  /// No description provided for @mapNoZonesSelectedYet.
  ///
  /// In en, this message translates to:
  /// **'No zones selected yet.'**
  String get mapNoZonesSelectedYet;

  /// No description provided for @mapMatchedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} matched'**
  String mapMatchedCount(Object count);

  /// No description provided for @mapSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get mapSelectAll;

  /// No description provided for @mapSelectAllInCity.
  ///
  /// In en, this message translates to:
  /// **'Select all in {city}'**
  String mapSelectAllInCity(Object city);

  /// No description provided for @mapClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get mapClearAll;

  /// No description provided for @mapSearchZonesOrCitiesHint.
  ///
  /// In en, this message translates to:
  /// **'Search zones or cities...'**
  String get mapSearchZonesOrCitiesHint;

  /// No description provided for @mapErrorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String mapErrorWithMessage(Object error);

  /// No description provided for @totalJobsLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Jobs'**
  String get totalJobsLabel;

  /// No description provided for @earningsLabel.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earningsLabel;

  /// No description provided for @visibleLabel.
  ///
  /// In en, this message translates to:
  /// **'Visible'**
  String get visibleLabel;

  /// No description provided for @postJobTitle.
  ///
  /// In en, this message translates to:
  /// **'Post a Job'**
  String get postJobTitle;

  /// No description provided for @postJobClassTitle.
  ///
  /// In en, this message translates to:
  /// **'Class Title'**
  String get postJobClassTitle;

  /// No description provided for @postJobClassType.
  ///
  /// In en, this message translates to:
  /// **'Class Type'**
  String get postJobClassType;

  /// No description provided for @postJobDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get postJobDate;

  /// No description provided for @postJobTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get postJobTime;

  /// No description provided for @postJobRateIls.
  ///
  /// In en, this message translates to:
  /// **'Rate (ILS)'**
  String get postJobRateIls;

  /// No description provided for @postJobNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get postJobNotesOptional;

  /// No description provided for @postJobInstructorEligibility.
  ///
  /// In en, this message translates to:
  /// **'Instructor Eligibility'**
  String get postJobInstructorEligibility;

  /// No description provided for @postJobTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Morning Vinyasa Flow'**
  String get postJobTitleHint;

  /// No description provided for @postJobStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get postJobStartLabel;

  /// No description provided for @postJobEndLabel.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get postJobEndLabel;

  /// No description provided for @postJobRateHint.
  ///
  /// In en, this message translates to:
  /// **'0'**
  String get postJobRateHint;

  /// No description provided for @postJobNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Any special requirements or notes for the instructor...'**
  String get postJobNotesHint;

  /// No description provided for @postJobSosTitle.
  ///
  /// In en, this message translates to:
  /// **'Priority dispatch'**
  String get postJobSosTitle;

  /// No description provided for @postJobSosDescription.
  ///
  /// In en, this message translates to:
  /// **'Jobs starting within 3 hours get priority notifications and boosted rates to attract instructors faster.'**
  String get postJobSosDescription;

  /// No description provided for @postJobButtonWithRate.
  ///
  /// In en, this message translates to:
  /// **'Post Job - ILS {rate}'**
  String postJobButtonWithRate(Object rate);

  /// No description provided for @postJobPleaseEnterClassTitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter a class title'**
  String get postJobPleaseEnterClassTitle;

  /// No description provided for @postJobPleaseSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get postJobPleaseSelectCategory;

  /// No description provided for @postJobPleaseEnterValidRate.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid rate'**
  String get postJobPleaseEnterValidRate;

  /// No description provided for @postJobVerifiedOnlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Verified instructors only'**
  String get postJobVerifiedOnlyLabel;

  /// No description provided for @postJobVerifiedOnlyHelp.
  ///
  /// In en, this message translates to:
  /// **'Enable to restrict this job to verified instructors.'**
  String get postJobVerifiedOnlyHelp;

  /// No description provided for @postJobLessonTypeRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select or type a lesson type so we can auto-tag the category.'**
  String get postJobLessonTypeRequired;

  /// No description provided for @postJobLessonTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Type lesson freely (e.g. reformer flow, vinyasa, hiit core)'**
  String get postJobLessonTypeHint;

  /// No description provided for @postJobCategoryYoga.
  ///
  /// In en, this message translates to:
  /// **'Yoga'**
  String get postJobCategoryYoga;

  /// No description provided for @postJobCategoryPilates.
  ///
  /// In en, this message translates to:
  /// **'Pilates'**
  String get postJobCategoryPilates;

  /// No description provided for @postJobCategoryReformerPilates.
  ///
  /// In en, this message translates to:
  /// **'Reformer Pilates'**
  String get postJobCategoryReformerPilates;

  /// No description provided for @postJobCategoryMatPilates.
  ///
  /// In en, this message translates to:
  /// **'Mat Pilates'**
  String get postJobCategoryMatPilates;

  /// No description provided for @postJobCategoryFunctionalTraining.
  ///
  /// In en, this message translates to:
  /// **'Functional Training'**
  String get postJobCategoryFunctionalTraining;

  /// No description provided for @postJobCategoryHiit.
  ///
  /// In en, this message translates to:
  /// **'HIIT'**
  String get postJobCategoryHiit;

  /// No description provided for @postJobCategoryStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get postJobCategoryStrength;

  /// No description provided for @postJobCategoryMobility.
  ///
  /// In en, this message translates to:
  /// **'Mobility'**
  String get postJobCategoryMobility;

  /// No description provided for @postJobCategoryBarre.
  ///
  /// In en, this message translates to:
  /// **'Barre'**
  String get postJobCategoryBarre;

  /// No description provided for @postJobCategorySpinning.
  ///
  /// In en, this message translates to:
  /// **'Spinning'**
  String get postJobCategorySpinning;

  /// No description provided for @postJobCategoryDance.
  ///
  /// In en, this message translates to:
  /// **'Dance'**
  String get postJobCategoryDance;

  /// No description provided for @postJobCategoryPersonalTraining.
  ///
  /// In en, this message translates to:
  /// **'Personal Training'**
  String get postJobCategoryPersonalTraining;

  /// No description provided for @postJobRateCurrency.
  ///
  /// In en, this message translates to:
  /// **'ILS'**
  String get postJobRateCurrency;

  /// No description provided for @postJobSosRateBonusLabel.
  ///
  /// In en, this message translates to:
  /// **'+15%'**
  String get postJobSosRateBonusLabel;

  /// No description provided for @postJobStudioLocationFallback.
  ///
  /// In en, this message translates to:
  /// **'Studio Location'**
  String get postJobStudioLocationFallback;

  /// No description provided for @postJobStudioAddressNotSet.
  ///
  /// In en, this message translates to:
  /// **'Studio address not set. Please complete onboarding first.'**
  String get postJobStudioAddressNotSet;

  /// No description provided for @postJobStartTimeFuture.
  ///
  /// In en, this message translates to:
  /// **'Start time must be in the future'**
  String get postJobStartTimeFuture;

  /// No description provided for @postJobEndTimeAfterStart.
  ///
  /// In en, this message translates to:
  /// **'End time must be after start time'**
  String get postJobEndTimeAfterStart;

  /// No description provided for @postJobSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Job posted! Instructors are being notified.'**
  String get postJobSuccessMessage;

  /// No description provided for @verifyCertificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Certification'**
  String get verifyCertificationTitle;

  /// No description provided for @uploadCertificateTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload Certificate'**
  String get uploadCertificateTitle;

  /// No description provided for @uploadCertificateDescription.
  ///
  /// In en, this message translates to:
  /// **'Upload a clear photo of your fitness instructor certification (Wingate, IFA, or equivalent).'**
  String get uploadCertificateDescription;

  /// No description provided for @submitForVerification.
  ///
  /// In en, this message translates to:
  /// **'Submit for Verification'**
  String get submitForVerification;

  /// No description provided for @verificationWhyTitle.
  ///
  /// In en, this message translates to:
  /// **'Why verify?'**
  String get verificationWhyTitle;

  /// No description provided for @verificationWhyDescription.
  ///
  /// In en, this message translates to:
  /// **'Verified instructors get priority in job matching and can charge higher rates. Studios trust verified profiles more.'**
  String get verificationWhyDescription;

  /// No description provided for @tapToUploadCertificate.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload certificate'**
  String get tapToUploadCertificate;

  /// No description provided for @uploadFileTypesHint.
  ///
  /// In en, this message translates to:
  /// **'JPG, PNG or PDF ? Max 10MB'**
  String get uploadFileTypesHint;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a Photo'**
  String get takePhoto;

  /// No description provided for @verificationVerifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Verified!'**
  String get verificationVerifiedTitle;

  /// No description provided for @verificationVerifiedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your certification has been verified successfully.'**
  String get verificationVerifiedSubtitle;

  /// No description provided for @verificationFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification Failed'**
  String get verificationFailedTitle;

  /// No description provided for @verificationFailedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t verify your certificate. Please upload a clearer image.'**
  String get verificationFailedSubtitle;

  /// No description provided for @verificationManualReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual Review'**
  String get verificationManualReviewTitle;

  /// No description provided for @verificationManualReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your certificate needs manual review by the team.'**
  String get verificationManualReviewSubtitle;

  /// No description provided for @verificationExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification Expired'**
  String get verificationExpiredTitle;

  /// No description provided for @verificationExpiredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your verification has expired. Please upload a new document.'**
  String get verificationExpiredSubtitle;

  /// No description provided for @verificationProcessingTitle.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get verificationProcessingTitle;

  /// No description provided for @verificationPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification Pending'**
  String get verificationPendingTitle;

  /// No description provided for @verificationPendingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'re reviewing your certificate. This usually takes a few minutes.'**
  String get verificationPendingSubtitle;

  /// No description provided for @verificationRequirementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Requirements'**
  String get verificationRequirementsTitle;

  /// No description provided for @verificationRequirementReadable.
  ///
  /// In en, this message translates to:
  /// **'Certificate must be clearly readable'**
  String get verificationRequirementReadable;

  /// No description provided for @verificationRequirementNameVisible.
  ///
  /// In en, this message translates to:
  /// **'Your name must be visible on the certificate'**
  String get verificationRequirementNameVisible;

  /// No description provided for @verificationRequirementRecognizedInstitution.
  ///
  /// In en, this message translates to:
  /// **'Certificate must be from a recognized institution'**
  String get verificationRequirementRecognizedInstitution;

  /// No description provided for @verificationRequirementExpiryVisible.
  ///
  /// In en, this message translates to:
  /// **'Expiry date (if applicable) must be visible'**
  String get verificationRequirementExpiryVisible;

  /// No description provided for @verificationUploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Certificate uploaded! AI verification in progress...'**
  String get verificationUploadSuccess;

  /// No description provided for @verificationUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String verificationUploadFailed(Object error);

  /// No description provided for @mapApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get mapApply;

  /// No description provided for @couldNotOpenGoogleCalendar.
  ///
  /// In en, this message translates to:
  /// **'Could not open Google Calendar.'**
  String get couldNotOpenGoogleCalendar;

  /// No description provided for @previousDayWindowTooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous day window'**
  String get previousDayWindowTooltip;

  /// No description provided for @todayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayLabel;

  /// No description provided for @nextDayWindowTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next day window'**
  String get nextDayWindowTooltip;

  /// No description provided for @swipeThreeDayWindowHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe left/right to move 3-day window'**
  String get swipeThreeDayWindowHint;

  /// No description provided for @addToGoogleCalendar.
  ///
  /// In en, this message translates to:
  /// **'Add to Google Calendar'**
  String get addToGoogleCalendar;

  /// No description provided for @studioJobsClaimAccepted.
  ///
  /// In en, this message translates to:
  /// **'Claim accepted!'**
  String get studioJobsClaimAccepted;

  /// No description provided for @studioJobsClaimRejected.
  ///
  /// In en, this message translates to:
  /// **'Claim rejected.'**
  String get studioJobsClaimRejected;

  /// No description provided for @studioJobsCompleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark class completed?'**
  String get studioJobsCompleteConfirmTitle;

  /// No description provided for @studioJobsCompleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This marks the job as completed and unlocks post-job rating.'**
  String get studioJobsCompleteConfirmBody;

  /// No description provided for @studioJobsCompleteConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Mark completed'**
  String get studioJobsCompleteConfirmAction;

  /// No description provided for @studioJobsCompleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Job marked as completed.'**
  String get studioJobsCompleteSuccess;

  /// No description provided for @studioJobsCompleteFailure.
  ///
  /// In en, this message translates to:
  /// **'Failed to complete job.'**
  String get studioJobsCompleteFailure;

  /// No description provided for @studioJobsBillingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get studioJobsBillingTooltip;

  /// No description provided for @studioJobsTabActiveWithCount.
  ///
  /// In en, this message translates to:
  /// **'Active ({count})'**
  String studioJobsTabActiveWithCount(Object count);

  /// No description provided for @studioJobsTabHistoryWithCount.
  ///
  /// In en, this message translates to:
  /// **'History ({count})'**
  String studioJobsTabHistoryWithCount(Object count);

  /// No description provided for @studioJobsSummaryActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get studioJobsSummaryActive;

  /// No description provided for @studioJobsSummaryHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get studioJobsSummaryHistory;

  /// No description provided for @studioJobsSummaryPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get studioJobsSummaryPayments;

  /// No description provided for @studioJobsSectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No jobs yet in this section.'**
  String get studioJobsSectionEmpty;

  /// No description provided for @studioJobsCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel job?'**
  String get studioJobsCancelTitle;

  /// No description provided for @studioJobsCancelBody.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get studioJobsCancelBody;

  /// No description provided for @studioJobsCancelNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get studioJobsCancelNo;

  /// No description provided for @studioJobsCancelYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, cancel'**
  String get studioJobsCancelYes;

  /// No description provided for @studioJobsCancelled.
  ///
  /// In en, this message translates to:
  /// **'Job cancelled.'**
  String get studioJobsCancelled;

  /// No description provided for @studioJobsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Jobs'**
  String get studioJobsTitle;

  /// No description provided for @studioJobsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get studioJobsRefresh;

  /// No description provided for @studioJobsPostJob.
  ///
  /// In en, this message translates to:
  /// **'Post Job'**
  String get studioJobsPostJob;

  /// No description provided for @studioJobsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load jobs: {error}'**
  String studioJobsLoadFailed(Object error);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @studioJobsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No jobs posted yet'**
  String get studioJobsEmptyTitle;

  /// No description provided for @studioJobsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Post a job to find instructors.'**
  String get studioJobsEmptyBody;

  /// No description provided for @studioJobsPostFirstJob.
  ///
  /// In en, this message translates to:
  /// **'Post your first job'**
  String get studioJobsPostFirstJob;

  /// No description provided for @studioJobsUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get studioJobsUntitled;

  /// No description provided for @studioJobsNoDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get studioJobsNoDate;

  /// No description provided for @studioJobsRate.
  ///
  /// In en, this message translates to:
  /// **'ILS {amount}'**
  String studioJobsRate(Object amount);

  /// No description provided for @studioJobsInstructorFallback.
  ///
  /// In en, this message translates to:
  /// **'Instructor'**
  String get studioJobsInstructorFallback;

  /// No description provided for @studioJobsVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get studioJobsVerified;

  /// No description provided for @studioJobsAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get studioJobsAccept;

  /// No description provided for @studioJobsReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get studioJobsReject;

  /// No description provided for @studioJobsStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get studioJobsStatusOpen;

  /// No description provided for @studioJobsStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get studioJobsStatusPending;

  /// No description provided for @studioJobsStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get studioJobsStatusConfirmed;

  /// No description provided for @studioJobsStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get studioJobsStatusCompleted;

  /// No description provided for @studioJobsStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get studioJobsStatusCancelled;

  /// No description provided for @studioAuthRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Studio session required'**
  String get studioAuthRequiredTitle;

  /// No description provided for @studioAuthRequiredBodyJobs.
  ///
  /// In en, this message translates to:
  /// **'You are not authenticated as a studio. Sign in again to view and post jobs.'**
  String get studioAuthRequiredBodyJobs;

  /// No description provided for @studioAuthRequiredBodyPostJob.
  ///
  /// In en, this message translates to:
  /// **'Sign in again as a studio to post jobs.'**
  String get studioAuthRequiredBodyPostJob;

  /// No description provided for @studioAuthRequiredSnack.
  ///
  /// In en, this message translates to:
  /// **'Studio authentication required. Please sign in again.'**
  String get studioAuthRequiredSnack;

  /// No description provided for @authGoToLogin.
  ///
  /// In en, this message translates to:
  /// **'Go to login'**
  String get authGoToLogin;

  /// No description provided for @profileStudioBillingTitle.
  ///
  /// In en, this message translates to:
  /// **'Billing & Invoicing'**
  String get profileStudioBillingTitle;

  /// No description provided for @profileStudioBillingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-issue invoices for instructor payments'**
  String get profileStudioBillingSubtitle;

  /// No description provided for @studioBillingProviderMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning (Green Invoice)'**
  String get studioBillingProviderMorning;

  /// No description provided for @studioBillingProviderIcount.
  ///
  /// In en, this message translates to:
  /// **'iCount'**
  String get studioBillingProviderIcount;

  /// No description provided for @studioBillingSummaryNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get studioBillingSummaryNotConnected;

  /// No description provided for @studioBillingSummaryMorningActive.
  ///
  /// In en, this message translates to:
  /// **'Morning active'**
  String get studioBillingSummaryMorningActive;

  /// No description provided for @studioBillingSummaryIcountActive.
  ///
  /// In en, this message translates to:
  /// **'iCount active'**
  String get studioBillingSummaryIcountActive;

  /// No description provided for @studioBillingSummaryConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get studioBillingSummaryConnected;

  /// No description provided for @studioBillingPlatformManagedNotice.
  ///
  /// In en, this message translates to:
  /// **'Payments are managed by QuickFit (Rapyd/BitPay). No studio payment setup is required.'**
  String get studioBillingPlatformManagedNotice;

  /// No description provided for @studioBillingInvoicingSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoicing'**
  String get studioBillingInvoicingSectionTitle;

  /// No description provided for @studioBillingNoProviderConnected.
  ///
  /// In en, this message translates to:
  /// **'No provider connected yet.'**
  String get studioBillingNoProviderConnected;

  /// No description provided for @studioBillingStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get studioBillingStatusActive;

  /// No description provided for @studioBillingStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get studioBillingStatusInactive;

  /// No description provided for @studioBillingMenuEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get studioBillingMenuEdit;

  /// No description provided for @studioBillingMenuSetInactive.
  ///
  /// In en, this message translates to:
  /// **'Set inactive'**
  String get studioBillingMenuSetInactive;

  /// No description provided for @studioBillingMenuSetActive.
  ///
  /// In en, this message translates to:
  /// **'Set active'**
  String get studioBillingMenuSetActive;

  /// No description provided for @studioBillingMenuRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get studioBillingMenuRemove;

  /// No description provided for @studioBillingConnectMorning.
  ///
  /// In en, this message translates to:
  /// **'Connect Morning'**
  String get studioBillingConnectMorning;

  /// No description provided for @studioBillingConnectIcount.
  ///
  /// In en, this message translates to:
  /// **'Connect iCount'**
  String get studioBillingConnectIcount;

  /// No description provided for @studioBillingBaseUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Base URL is required'**
  String get studioBillingBaseUrlRequired;

  /// No description provided for @studioBillingBaseUrlHttpsRequired.
  ///
  /// In en, this message translates to:
  /// **'Base URL must start with https://'**
  String get studioBillingBaseUrlHttpsRequired;

  /// No description provided for @studioBillingApiTokenRequired.
  ///
  /// In en, this message translates to:
  /// **'API token is required'**
  String get studioBillingApiTokenRequired;

  /// No description provided for @studioBillingApiKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'API key is required'**
  String get studioBillingApiKeyRequired;

  /// No description provided for @studioBillingConnected.
  ///
  /// In en, this message translates to:
  /// **'{provider} connected'**
  String studioBillingConnected(Object provider);

  /// No description provided for @studioBillingConnectProvider.
  ///
  /// In en, this message translates to:
  /// **'Connect {provider}'**
  String studioBillingConnectProvider(Object provider);

  /// No description provided for @studioBillingEditProvider.
  ///
  /// In en, this message translates to:
  /// **'Edit {provider}'**
  String studioBillingEditProvider(Object provider);

  /// No description provided for @studioBillingBaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get studioBillingBaseUrlLabel;

  /// No description provided for @studioBillingApiTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'API token (leave empty to keep existing)'**
  String get studioBillingApiTokenLabel;

  /// No description provided for @studioBillingApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API key (leave empty to keep existing)'**
  String get studioBillingApiKeyLabel;

  /// No description provided for @studioBillingAccountIdOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Account ID (optional)'**
  String get studioBillingAccountIdOptionalLabel;

  /// No description provided for @studioBillingDefaultVatOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Default VAT rate (optional)'**
  String get studioBillingDefaultVatOptionalLabel;

  /// No description provided for @profileStudioPricingTitle.
  ///
  /// In en, this message translates to:
  /// **'Default Pricing'**
  String get profileStudioPricingTitle;

  /// No description provided for @profileStudioPricingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Base rate and lead-time surge rules'**
  String get profileStudioPricingSubtitle;

  /// No description provided for @profileStudioPricingDefaultRate.
  ///
  /// In en, this message translates to:
  /// **'Default base rate (ILS)'**
  String get profileStudioPricingDefaultRate;

  /// No description provided for @profileStudioPricingRuleHours.
  ///
  /// In en, this message translates to:
  /// **'Window (hours before start)'**
  String get profileStudioPricingRuleHours;

  /// No description provided for @profileStudioPricingRuleBoost.
  ///
  /// In en, this message translates to:
  /// **'Boost (%)'**
  String get profileStudioPricingRuleBoost;

  /// No description provided for @profileStudioPricingAddRule.
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get profileStudioPricingAddRule;

  /// No description provided for @profileStudioPricingSaved.
  ///
  /// In en, this message translates to:
  /// **'Studio pricing updated.'**
  String get profileStudioPricingSaved;

  /// No description provided for @profileStudioPricingSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update studio pricing.'**
  String get profileStudioPricingSaveFailed;

  /// No description provided for @profileStudioPricingSummary.
  ///
  /// In en, this message translates to:
  /// **'ILS {rate}, {rules}'**
  String profileStudioPricingSummary(Object rate, Object rules);

  /// No description provided for @profileStudioPricingRuleCompact.
  ///
  /// In en, this message translates to:
  /// **'{hours}h:+{boost}%'**
  String profileStudioPricingRuleCompact(Object hours, Object boost);

  /// No description provided for @profileStudioPublicJobsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Available Jobs'**
  String get profileStudioPublicJobsTitle;

  /// No description provided for @profileStudioPublicJobsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View public profile with active jobs'**
  String get profileStudioPublicJobsSubtitle;

  /// No description provided for @profileStudioActiveJobsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String profileStudioActiveJobsCount(Object count);

  /// No description provided for @studioPublicProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Studio Profile'**
  String get studioPublicProfileTitle;

  /// No description provided for @studioPublicProfileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Studio not found'**
  String get studioPublicProfileNotFound;

  /// No description provided for @studioPublicProfileFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Studio'**
  String get studioPublicProfileFallbackName;

  /// No description provided for @studioPublicProfileOpenJobsCount.
  ///
  /// In en, this message translates to:
  /// **'Open jobs: {count}'**
  String studioPublicProfileOpenJobsCount(Object count);

  /// No description provided for @studioPublicProfileActiveJobsCount.
  ///
  /// In en, this message translates to:
  /// **'Active jobs: {count}'**
  String studioPublicProfileActiveJobsCount(Object count);

  /// No description provided for @studioPublicProfileAvailableJobsTitle.
  ///
  /// In en, this message translates to:
  /// **'Available Jobs'**
  String get studioPublicProfileAvailableJobsTitle;

  /// No description provided for @studioPublicProfileNoAvailableJobs.
  ///
  /// In en, this message translates to:
  /// **'No available jobs right now.'**
  String get studioPublicProfileNoAvailableJobs;

  /// No description provided for @studioPublicProfileUntitledClass.
  ///
  /// In en, this message translates to:
  /// **'Untitled class'**
  String get studioPublicProfileUntitledClass;

  /// No description provided for @studioPublicProfileCategoryFallback.
  ///
  /// In en, this message translates to:
  /// **'general'**
  String get studioPublicProfileCategoryFallback;

  /// No description provided for @studioPublicProfileRateCurrency.
  ///
  /// In en, this message translates to:
  /// **'ILS'**
  String get studioPublicProfileRateCurrency;

  /// No description provided for @studioPublicProfilePostedAt.
  ///
  /// In en, this message translates to:
  /// **'Posted {time}'**
  String studioPublicProfilePostedAt(Object time);

  /// No description provided for @jobDetailClaimQueued.
  ///
  /// In en, this message translates to:
  /// **'Claim request queued.'**
  String get jobDetailClaimQueued;

  /// No description provided for @jobDetailWithdrawalQueued.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal request queued.'**
  String get jobDetailWithdrawalQueued;

  /// No description provided for @jobDetailNoActiveClaim.
  ///
  /// In en, this message translates to:
  /// **'No active claim found.'**
  String get jobDetailNoActiveClaim;

  /// No description provided for @jobDetailClaimRejected.
  ///
  /// In en, this message translates to:
  /// **'Claim rejected.'**
  String get jobDetailClaimRejected;

  /// No description provided for @jobDetailActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed: {error}'**
  String jobDetailActionFailed(Object error);

  /// No description provided for @jobDetailCancelled.
  ///
  /// In en, this message translates to:
  /// **'Job cancelled.'**
  String get jobDetailCancelled;

  /// No description provided for @jobDetailCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel: {error}'**
  String jobDetailCancelFailed(Object error);

  /// No description provided for @jobDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Job Details'**
  String get jobDetailTitle;

  /// No description provided for @jobDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Job not found'**
  String get jobDetailNotFound;

  /// No description provided for @jobDetailSosBoost.
  ///
  /// In en, this message translates to:
  /// **'SOS BOOST'**
  String get jobDetailSosBoost;

  /// No description provided for @jobDetailDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Fitness Class'**
  String get jobDetailDefaultTitle;

  /// No description provided for @jobDetailDefaultStudio.
  ///
  /// In en, this message translates to:
  /// **'Studio'**
  String get jobDetailDefaultStudio;

  /// No description provided for @jobDetailDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get jobDetailDate;

  /// No description provided for @jobDetailTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get jobDetailTime;

  /// No description provided for @jobDetailLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get jobDetailLocation;

  /// No description provided for @jobDetailDefaultLocation.
  ///
  /// In en, this message translates to:
  /// **'Israel'**
  String get jobDetailDefaultLocation;

  /// No description provided for @jobDetailRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get jobDetailRate;

  /// No description provided for @jobDetailRequirements.
  ///
  /// In en, this message translates to:
  /// **'Requirements & Notes'**
  String get jobDetailRequirements;

  /// No description provided for @jobDetailNoRequirements.
  ///
  /// In en, this message translates to:
  /// **'No special requirements listed.'**
  String get jobDetailNoRequirements;

  /// No description provided for @jobDetailClaimBackup.
  ///
  /// In en, this message translates to:
  /// **'Claim as Backup'**
  String get jobDetailClaimBackup;

  /// No description provided for @jobDetailClaimPrimary.
  ///
  /// In en, this message translates to:
  /// **'Claim this Job'**
  String get jobDetailClaimPrimary;

  /// No description provided for @jobDetailBackupHint.
  ///
  /// In en, this message translates to:
  /// **'This job is claimed, but you can join as a backup.'**
  String get jobDetailBackupHint;

  /// No description provided for @jobDetailClaimedBy.
  ///
  /// In en, this message translates to:
  /// **'Claimed By'**
  String get jobDetailClaimedBy;

  /// No description provided for @jobDetailRejectClaim.
  ///
  /// In en, this message translates to:
  /// **'Reject Claim'**
  String get jobDetailRejectClaim;

  /// No description provided for @jobDetailAcceptClaim.
  ///
  /// In en, this message translates to:
  /// **'Accept Claim'**
  String get jobDetailAcceptClaim;

  /// No description provided for @jobDetailPrimaryRole.
  ///
  /// In en, this message translates to:
  /// **'You are the primary instructor.'**
  String get jobDetailPrimaryRole;

  /// No description provided for @jobDetailBackupRole.
  ///
  /// In en, this message translates to:
  /// **'You are an assigned backup.'**
  String get jobDetailBackupRole;

  /// No description provided for @jobDetailProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get jobDetailProcessing;

  /// No description provided for @jobDetailCancelClaim.
  ///
  /// In en, this message translates to:
  /// **'Cancel Claim'**
  String get jobDetailCancelClaim;

  /// No description provided for @jobDetailUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get jobDetailUnknown;

  /// No description provided for @jobDetailVerifiedProfessional.
  ///
  /// In en, this message translates to:
  /// **'Verified Professional'**
  String get jobDetailVerifiedProfessional;

  /// No description provided for @jobDetailCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Job?'**
  String get jobDetailCancelTitle;

  /// No description provided for @jobDetailCancelBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this job? This cannot be undone.'**
  String get jobDetailCancelBody;

  /// No description provided for @jobDetailKeepIt.
  ///
  /// In en, this message translates to:
  /// **'Keep It'**
  String get jobDetailKeepIt;

  /// No description provided for @jobDetailCancelCta.
  ///
  /// In en, this message translates to:
  /// **'Cancel Job'**
  String get jobDetailCancelCta;

  /// No description provided for @onboardingLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not get your location. Try entering your address.'**
  String get onboardingLocationUnavailable;

  /// No description provided for @onboardingLocationNotFound.
  ///
  /// In en, this message translates to:
  /// **'Could not find location. Please select from the list or use GPS.'**
  String get onboardingLocationNotFound;

  /// No description provided for @onboardingStudioLocationRequired.
  ///
  /// In en, this message translates to:
  /// **'Studio location required. Please enter a valid address.'**
  String get onboardingStudioLocationRequired;

  /// No description provided for @onboardingSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to complete setup. Please try again.'**
  String get onboardingSetupFailed;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome.'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Choose your role to continue.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingRoleInstructor.
  ///
  /// In en, this message translates to:
  /// **'Instructor'**
  String get onboardingRoleInstructor;

  /// No description provided for @onboardingRoleInstructorBody.
  ///
  /// In en, this message translates to:
  /// **'Find sub jobs at studios near you and grow your network.'**
  String get onboardingRoleInstructorBody;

  /// No description provided for @onboardingRoleStudio.
  ///
  /// In en, this message translates to:
  /// **'Studio'**
  String get onboardingRoleStudio;

  /// No description provided for @onboardingRoleStudioBody.
  ///
  /// In en, this message translates to:
  /// **'Post classes and find reliable instructors in minutes.'**
  String get onboardingRoleStudioBody;

  /// No description provided for @onboardingBuildProfile.
  ///
  /// In en, this message translates to:
  /// **'Build your profile.'**
  String get onboardingBuildProfile;

  /// No description provided for @onboardingFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get onboardingFullName;

  /// No description provided for @onboardingStudioName.
  ///
  /// In en, this message translates to:
  /// **'Studio Name'**
  String get onboardingStudioName;

  /// No description provided for @onboardingAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get onboardingAddress;

  /// No description provided for @onboardingAddressHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Rothschild 1, Tel Aviv'**
  String get onboardingAddressHint;

  /// No description provided for @onboardingUseCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use Current Location'**
  String get onboardingUseCurrentLocation;

  /// No description provided for @onboardingYourExpertise.
  ///
  /// In en, this message translates to:
  /// **'Your Expertise'**
  String get onboardingYourExpertise;

  /// No description provided for @onboardingCoverageZones.
  ///
  /// In en, this message translates to:
  /// **'Coverage Zones'**
  String get onboardingCoverageZones;

  /// No description provided for @onboardingSearchRadius.
  ///
  /// In en, this message translates to:
  /// **'Search Radius'**
  String get onboardingSearchRadius;

  /// No description provided for @onboardingZoneHint.
  ///
  /// In en, this message translates to:
  /// **'Tap zones on the map to select your coverage areas.'**
  String get onboardingZoneHint;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingNextStep.
  ///
  /// In en, this message translates to:
  /// **'Next Step'**
  String get onboardingNextStep;

  /// No description provided for @onboardingTipFastMatchingTitle.
  ///
  /// In en, this message translates to:
  /// **'Fast Matching'**
  String get onboardingTipFastMatchingTitle;

  /// No description provided for @onboardingTipFastMatchingBody.
  ///
  /// In en, this message translates to:
  /// **'Connect with studios in real-time.'**
  String get onboardingTipFastMatchingBody;

  /// No description provided for @onboardingTipVerifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Verified Pros'**
  String get onboardingTipVerifiedTitle;

  /// No description provided for @onboardingTipVerifiedBody.
  ///
  /// In en, this message translates to:
  /// **'Join a community of certified instructors.'**
  String get onboardingTipVerifiedBody;

  /// No description provided for @onboardingTipLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'Local Focus'**
  String get onboardingTipLocalTitle;

  /// No description provided for @onboardingTipLocalBody.
  ///
  /// In en, this message translates to:
  /// **'Work exactly where you want to.'**
  String get onboardingTipLocalBody;

  /// No description provided for @onboardingPreview.
  ///
  /// In en, this message translates to:
  /// **'PREVIEW'**
  String get onboardingPreview;

  /// No description provided for @onboardingYourName.
  ///
  /// In en, this message translates to:
  /// **'Your Name'**
  String get onboardingYourName;

  /// No description provided for @onboardingUnselected.
  ///
  /// In en, this message translates to:
  /// **'UNSELECTED'**
  String get onboardingUnselected;

  /// No description provided for @onboardingSelectCategoriesHint.
  ///
  /// In en, this message translates to:
  /// **'Select categories to see them here.'**
  String get onboardingSelectCategoriesHint;

  /// No description provided for @onboardingRadiusLabel.
  ///
  /// In en, this message translates to:
  /// **'{value} km radius'**
  String onboardingRadiusLabel(Object value);

  /// No description provided for @onboardingFindMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Find My Location'**
  String get onboardingFindMyLocation;

  /// No description provided for @onboardingCouldNotLoadZones.
  ///
  /// In en, this message translates to:
  /// **'Could not load zones'**
  String get onboardingCouldNotLoadZones;

  /// No description provided for @onboardingTryRadiusMode.
  ///
  /// In en, this message translates to:
  /// **'Try radius mode instead'**
  String get onboardingTryRadiusMode;

  /// No description provided for @onboardingSetYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Set Your Location'**
  String get onboardingSetYourLocation;

  /// No description provided for @onboardingSetYourLocationBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your address in the form, or use GPS:'**
  String get onboardingSetYourLocationBody;

  /// No description provided for @mapRadiusKm.
  ///
  /// In en, this message translates to:
  /// **'{value} km'**
  String mapRadiusKm(Object value);
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
