// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Quickfit';

  @override
  String get loading => 'Loading...';

  @override
  String get pageNotFound => 'Page not found';

  @override
  String get goHome => 'Go Home';

  @override
  String get loginTagline => 'Find replacement instructors fast';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get continueWithEmail => 'Continue with Email';

  @override
  String get or => 'or';

  @override
  String get back => 'Back';

  @override
  String get createAccount => 'Create Account';

  @override
  String get signIn => 'Sign In';

  @override
  String get nameLabel => 'Name';

  @override
  String get displayNameLabel => 'Display Name';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get emailInvalid => 'Enter a valid email';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get passwordMinLength => 'Password must be at least 6 characters';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign In';

  @override
  String get dontHaveAccount => 'Don\'t have an account? Sign Up';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get passwordResetSent => 'Password reset email sent';

  @override
  String get enterEmailFirst => 'Enter your email first';

  @override
  String get termsPrefix => 'By continuing, you agree to our ';

  @override
  String get and => 'and';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get profileInfo => 'Profile Info';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get homeAddress => 'Home Address';

  @override
  String get addressHint => 'e.g., Rothschild 1, Tel Aviv';

  @override
  String get searchRadius => 'Search Radius';

  @override
  String get maximumDistance => 'Maximum Distance';

  @override
  String get expertise => 'Expertise';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get profileUpdated => 'Profile updated successfully';

  @override
  String get account => 'Account';

  @override
  String get notSet => 'Not set';

  @override
  String get email => 'Email';

  @override
  String get workRadius => 'Work Radius';

  @override
  String get teachingCategories => 'Teaching Categories';

  @override
  String get classTypes => 'Class Types';

  @override
  String get settings => 'Settings';

  @override
  String get linkedAccounts => 'Linked Accounts';

  @override
  String get none => 'None';

  @override
  String get addPassword => 'Add Password';

  @override
  String get enableEmailLogin => 'Enable email login';

  @override
  String get notifications => 'Notifications';

  @override
  String get redoOnboarding => 'Redo Onboarding';

  @override
  String get redoOnboardingPrompt =>
      'This will let you choose your role and profile data again.';

  @override
  String get redo => 'Redo';

  @override
  String get cancel => 'Cancel';

  @override
  String get language => 'Language';

  @override
  String get helpSupport => 'Help & Support';

  @override
  String get signOut => 'Sign Out';

  @override
  String get verify => 'Verify';

  @override
  String get verifiedCredentials => 'Your credentials have been verified';

  @override
  String get uploadCredentials => 'Upload your certification to get verified';

  @override
  String get notificationsLabelOff => 'Off';

  @override
  String get notificationsLabelAll => 'All';

  @override
  String get notificationsLabelSosOnly => 'SOS only';

  @override
  String get notificationsLabelRegularOnly => 'Regular only';

  @override
  String get notificationsLabelMuted => 'Muted';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEnable => 'Enable Alerts';

  @override
  String get notificationsRegular => 'Regular Jobs';

  @override
  String get notificationsSos => 'SOS Jobs';

  @override
  String get save => 'Save';

  @override
  String get languageRestartPrompt => 'Restart app to apply language.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHebrew => 'עברית';

  @override
  String get close => 'Close';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get filterJobsTitle => 'Filter Jobs';

  @override
  String get reset => 'Reset';

  @override
  String get categoryLabel => 'Category';

  @override
  String minimumRateLabelWithValue(Object currency, Object value) {
    return 'Minimum Rate: $currency $value';
  }

  @override
  String get currencyILS => 'ILS';

  @override
  String currencyAmount(Object currency, Object amount) {
    return '$currency $amount';
  }

  @override
  String get applyFilters => 'Apply Filters';

  @override
  String jobClaimedNotification(Object studioName) {
    return 'Job claimed! $studioName will be notified.';
  }

  @override
  String get availableJobsTitle => 'Available Jobs';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get noJobsAvailable => 'No jobs available';

  @override
  String get noJobsAvailableHint =>
      'Check back soon or expand your search radius in settings.';

  @override
  String get refresh => 'Refresh';

  @override
  String get urgentJobsTitle => 'Urgent Jobs';

  @override
  String get pullToRefresh => 'Pull down to refresh';

  @override
  String get noJobsMatchFilters => 'No jobs match your filters';

  @override
  String get clearFilters => 'Clear Filters';

  @override
  String get supportPlaceholder =>
      'Support contact is not configured yet. Add support details in your app settings when ready.';

  @override
  String get termsPlaceholder =>
      'Terms of Service are not configured yet. Add your terms copy here when ready.';

  @override
  String get privacyPlaceholder =>
      'Privacy Policy is not configured yet. Add your policy copy here when ready.';

  @override
  String versionLabel(Object version) {
    return 'Quickfit v$version';
  }

  @override
  String radiusKmLabel(Object value) {
    return '$value km';
  }

  @override
  String zonesSelectedLabel(Object count) {
    return '$count zones selected';
  }
}
