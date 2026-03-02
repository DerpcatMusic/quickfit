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
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

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
  String get changeEmail => 'Change Email';

  @override
  String get newEmailLabel => 'New Email';

  @override
  String get currentPasswordLabel => 'Current Password';

  @override
  String get currentPasswordRequired => 'Current password is required';

  @override
  String get emailUnchanged => 'Please enter a different email';

  @override
  String get sendVerification => 'Send Verification';

  @override
  String get emailChangeVerificationSent =>
      'Verification email sent. Confirm it to complete your email change.';

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
  String get submit => 'Submit';

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
  String get sosLabel => 'SOS';

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
  String get profileRoleStudio => 'Studio';

  @override
  String get profileRoleInstructor => 'Instructor';

  @override
  String get profileAnonymousUser => 'Anonymous User';

  @override
  String get profileUseAccountPhoto => 'Use account photo';

  @override
  String get profileUseAccountPhotoUnavailable =>
      'No account photo available to use.';

  @override
  String get profileUseAccountPhotoApplied =>
      'Profile photo updated from account.';

  @override
  String get profileUseAccountPhotoFailed => 'Failed to update profile photo.';

  @override
  String get profileProviderGoogle => 'Google';

  @override
  String get profileProviderApple => 'Apple';

  @override
  String get profileProviderEmail => 'Email';

  @override
  String get profileProviderOauth => 'OAuth';

  @override
  String profileEmailManagedByProvider(Object providersLabel) {
    return 'Email is managed by $providersLabel and cannot be edited directly in the app yet.';
  }

  @override
  String profileEmailManagedByProviderWithFallback(Object providersLabel) {
    return 'Email is managed by $providersLabel and cannot be edited directly in the app yet. You can also add password login as a fallback.';
  }

  @override
  String get profileDisplayNameRequired => 'Display name is required';

  @override
  String get profileVerifiedInstructor => 'Verified Instructor';

  @override
  String profileAddPasswordDescription(Object email) {
    return 'Add a password to allow signing in with email ($email)';
  }

  @override
  String get profilePasswordPlaceholder => 'Password (6+ chars)';

  @override
  String get profilePasswordAddedSuccess =>
      'Password added! You can now sign in with email.';

  @override
  String get profilePasswordAddFailed => 'Failed to add password';

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

  @override
  String get calendarTitle => 'Calendar';

  @override
  String syncedAt(Object time) {
    return 'Synced $time';
  }

  @override
  String get noJobsInThreeDayWindow => 'No jobs in this 3-day window.';

  @override
  String scheduleHoursCompact(Object hours) {
    return '${hours}h';
  }

  @override
  String scheduleGoogleCalendarDetailsHeader(Object jobId) {
    return 'QuickFit job #$jobId';
  }

  @override
  String scheduleGoogleCalendarDetailsStudio(Object studioName) {
    return 'Studio: $studioName';
  }

  @override
  String get instructorMapServiceArea => 'Service Area';

  @override
  String instructorMapLiveJobsInView(Object count) {
    return '$count live jobs in view';
  }

  @override
  String get instructorMapTapToDropPin => 'Tap the map once to drop your pin.';

  @override
  String get instructorMapPinUpdatedTapSave =>
      'Pin updated. Tap Save Changes to apply.';

  @override
  String get instructorMapTypeAddressToMovePin => 'Type address to move pin';

  @override
  String get instructorMapAddressNotFound =>
      'Address not found. Try a more specific address.';

  @override
  String get instructorMapPleaseSelectLocation =>
      'Please select a location on the map';

  @override
  String get instructorMapPleaseSelectOneZone =>
      'Please select at least one zone';

  @override
  String get instructorMapSettingsSaved => 'Settings saved successfully';

  @override
  String instructorMapErrorSavingSettings(Object error) {
    return 'Error saving settings: $error';
  }

  @override
  String get instructorMapMapSettingsTooltip => 'Map settings';

  @override
  String get instructorMapDropPinTooltip => 'Drop pin';

  @override
  String get instructorMapApplyAddressTooltip => 'Apply address';

  @override
  String get mapSettingsTitle => 'Map Settings';

  @override
  String get mapSettingsSubtitle =>
      'Adjust how and where job matches are discovered.';

  @override
  String get mapModeRadius => 'Radius';

  @override
  String get mapModeZones => 'Zones';

  @override
  String get saving => 'Saving...';

  @override
  String get mapSearchRadius => 'Search Radius';

  @override
  String get mapSelectedZones => 'Selected Zones';

  @override
  String mapActiveCount(Object count) {
    return '$count active';
  }

  @override
  String get mapZoneSelectionHint =>
      'Zone selection is done directly on the map. Close this sheet to edit zones.';

  @override
  String get mapLoadingZones => 'Loading zones...';

  @override
  String get mapNoZonesSelectedYet => 'No zones selected yet.';

  @override
  String mapMatchedCount(Object count) {
    return '$count matched';
  }

  @override
  String get mapSelectAll => 'Select All';

  @override
  String mapSelectAllInCity(Object city) {
    return 'Select all in $city';
  }

  @override
  String get mapClearAll => 'Clear All';

  @override
  String get mapSearchZonesOrCitiesHint => 'Search zones or cities...';

  @override
  String mapErrorWithMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get totalJobsLabel => 'Total Jobs';

  @override
  String get earningsLabel => 'Earnings';

  @override
  String get visibleLabel => 'Visible';

  @override
  String get postJobTitle => 'Post a Job';

  @override
  String get postJobClassTitle => 'Class Title';

  @override
  String get postJobClassType => 'Class Type';

  @override
  String get postJobDate => 'Date';

  @override
  String get postJobTime => 'Time';

  @override
  String get postJobRateIls => 'Rate (ILS)';

  @override
  String get postJobNotesOptional => 'Notes (optional)';

  @override
  String get postJobInstructorEligibility => 'Instructor Eligibility';

  @override
  String get postJobTitleHint => 'e.g. Morning Vinyasa Flow';

  @override
  String get postJobStartLabel => 'Start';

  @override
  String get postJobEndLabel => 'End';

  @override
  String get postJobRateHint => '0';

  @override
  String get postJobNotesHint =>
      'Any special requirements or notes for the instructor...';

  @override
  String get postJobSosTitle => 'Priority dispatch';

  @override
  String get postJobSosDescription =>
      'Jobs starting within 3 hours get priority notifications and boosted rates to attract instructors faster.';

  @override
  String postJobButtonWithRate(Object rate) {
    return 'Post Job - ILS $rate';
  }

  @override
  String get postJobPleaseEnterClassTitle => 'Please enter a class title';

  @override
  String get postJobPleaseSelectCategory => 'Please select a category';

  @override
  String get postJobPleaseEnterValidRate => 'Please enter a valid rate';

  @override
  String get postJobVerifiedOnlyLabel => 'Verified instructors only';

  @override
  String get postJobVerifiedOnlyHelp =>
      'Enable to restrict this job to verified instructors.';

  @override
  String get postJobLessonTypeRequired =>
      'Please select or type a lesson type so we can auto-tag the category.';

  @override
  String get postJobLessonTypeHint =>
      'Type lesson freely (e.g. reformer flow, vinyasa, hiit core)';

  @override
  String get postJobCategoryYoga => 'Yoga';

  @override
  String get postJobCategoryPilates => 'Pilates';

  @override
  String get postJobCategoryReformerPilates => 'Reformer Pilates';

  @override
  String get postJobCategoryMatPilates => 'Mat Pilates';

  @override
  String get postJobCategoryFunctionalTraining => 'Functional Training';

  @override
  String get postJobCategoryHiit => 'HIIT';

  @override
  String get postJobCategoryStrength => 'Strength';

  @override
  String get postJobCategoryMobility => 'Mobility';

  @override
  String get postJobCategoryBarre => 'Barre';

  @override
  String get postJobCategorySpinning => 'Spinning';

  @override
  String get postJobCategoryDance => 'Dance';

  @override
  String get postJobCategoryPersonalTraining => 'Personal Training';

  @override
  String get postJobRateCurrency => 'ILS';

  @override
  String postJobRateBoostPill(Object boostPercent) {
    return '+$boostPercent%';
  }

  @override
  String get postJobSosRateBonusLabel => '+15%';

  @override
  String get postJobStudioLocationFallback => 'Studio Location';

  @override
  String get postJobStudioAddressNotSet =>
      'Studio address not set. Please complete onboarding first.';

  @override
  String get postJobStartTimeFuture => 'Start time must be in the future';

  @override
  String get postJobEndTimeAfterStart => 'End time must be after start time';

  @override
  String get postJobSuccessMessage =>
      'Job posted! Instructors are being notified.';

  @override
  String get verifyCertificationTitle => 'Verify Certification';

  @override
  String get uploadCertificateTitle => 'Upload Certificate';

  @override
  String get uploadCertificateDescription =>
      'Upload a clear photo of your fitness instructor certification (Wingate, IFA, or equivalent).';

  @override
  String get submitForVerification => 'Submit for Verification';

  @override
  String get verificationWhyTitle => 'Why verify?';

  @override
  String get verificationWhyDescription =>
      'Verified instructors get priority in job matching and can charge higher rates. Studios trust verified profiles more.';

  @override
  String get tapToUploadCertificate => 'Tap to upload certificate';

  @override
  String get uploadFileTypesHint => 'JPG, PNG or PDF ? Max 10MB';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get takePhoto => 'Take a Photo';

  @override
  String get verificationVerifiedTitle => 'Verified!';

  @override
  String get verificationVerifiedSubtitle =>
      'Your certification has been verified successfully.';

  @override
  String get verificationFailedTitle => 'Verification Failed';

  @override
  String get verificationFailedSubtitle =>
      'We couldn\'t verify your certificate. Please upload a clearer image.';

  @override
  String get verificationManualReviewTitle => 'Manual Review';

  @override
  String get verificationManualReviewSubtitle =>
      'Your certificate needs manual review by the team.';

  @override
  String get verificationExpiredTitle => 'Verification Expired';

  @override
  String get verificationExpiredSubtitle =>
      'Your verification has expired. Please upload a new document.';

  @override
  String get verificationProcessingTitle => 'Processing';

  @override
  String get verificationPendingTitle => 'Verification Pending';

  @override
  String get verificationPendingSubtitle =>
      'We\'re reviewing your certificate. This usually takes a few minutes.';

  @override
  String get verificationRequirementsTitle => 'Requirements';

  @override
  String get verificationRequirementReadable =>
      'Certificate must be clearly readable';

  @override
  String get verificationRequirementNameVisible =>
      'Your name must be visible on the certificate';

  @override
  String get verificationRequirementRecognizedInstitution =>
      'Certificate must be from a recognized institution';

  @override
  String get verificationRequirementExpiryVisible =>
      'Expiry date (if applicable) must be visible';

  @override
  String get verificationUploadSuccess =>
      'Certificate uploaded! AI verification in progress...';

  @override
  String verificationUploadFailed(Object error) {
    return 'Upload failed: $error';
  }

  @override
  String get mapApply => 'Apply';

  @override
  String get couldNotOpenGoogleCalendar => 'Could not open Google Calendar.';

  @override
  String get previousDayWindowTooltip => 'Previous day window';

  @override
  String get todayLabel => 'Today';

  @override
  String get nextDayWindowTooltip => 'Next day window';

  @override
  String get swipeThreeDayWindowHint => 'Swipe left/right to move 3-day window';

  @override
  String get addToGoogleCalendar => 'Add to Google Calendar';

  @override
  String get studioJobsClaimAccepted => 'Claim accepted!';

  @override
  String get studioJobsClaimRejected => 'Claim rejected.';

  @override
  String get studioJobsCompleteConfirmTitle => 'Mark class completed?';

  @override
  String get studioJobsCompleteConfirmBody =>
      'This marks the job as completed and unlocks post-job rating.';

  @override
  String get studioJobsCompleteConfirmAction => 'Mark completed';

  @override
  String get studioJobsCompleteSuccess => 'Job marked as completed.';

  @override
  String get studioJobsCompleteFailure => 'Failed to complete job.';

  @override
  String get studioJobsBillingTooltip => 'Billing';

  @override
  String studioJobsTabActiveWithCount(Object count) {
    return 'Active ($count)';
  }

  @override
  String studioJobsTabHistoryWithCount(Object count) {
    return 'History ($count)';
  }

  @override
  String get studioJobsSummaryActive => 'Active';

  @override
  String get studioJobsSummaryHistory => 'History';

  @override
  String get studioJobsSummaryPayments => 'Payments';

  @override
  String get studioJobsSectionEmpty => 'No jobs yet in this section.';

  @override
  String get studioJobsCancelTitle => 'Cancel job?';

  @override
  String get studioJobsCancelBody => 'This action cannot be undone.';

  @override
  String get studioJobsCancelNo => 'No';

  @override
  String get studioJobsCancelYes => 'Yes, cancel';

  @override
  String get studioJobsCancelled => 'Job cancelled.';

  @override
  String get studioJobsTitle => 'My Jobs';

  @override
  String get studioJobsRefresh => 'Refresh';

  @override
  String get studioJobsPostJob => 'Post Job';

  @override
  String studioJobsLoadFailed(Object error) {
    return 'Failed to load jobs: $error';
  }

  @override
  String get retry => 'Retry';

  @override
  String get studioJobsEmptyTitle => 'No jobs posted yet';

  @override
  String get studioJobsEmptyBody => 'Post a job to find instructors.';

  @override
  String get studioJobsPostFirstJob => 'Post your first job';

  @override
  String get studioJobsUntitled => 'Untitled';

  @override
  String get studioJobsNoDate => 'No date';

  @override
  String studioJobsRate(Object amount) {
    return 'ILS $amount';
  }

  @override
  String get studioJobsInstructorFallback => 'Instructor';

  @override
  String get studioJobsVerified => 'Verified';

  @override
  String get studioJobsAccept => 'Accept';

  @override
  String get studioJobsReject => 'Reject';

  @override
  String get studioJobsStatusOpen => 'Open';

  @override
  String get studioJobsStatusPending => 'Pending';

  @override
  String get studioJobsStatusConfirmed => 'Confirmed';

  @override
  String get studioJobsStatusCompleted => 'Completed';

  @override
  String get studioJobsStatusCancelled => 'Cancelled';

  @override
  String get studioAuthRequiredTitle => 'Studio session required';

  @override
  String get studioAuthRequiredBodyJobs =>
      'You are not authenticated as a studio. Sign in again to view and post jobs.';

  @override
  String get studioAuthRequiredBodyPostJob =>
      'Sign in again as a studio to post jobs.';

  @override
  String get studioAuthRequiredSnack =>
      'Studio authentication required. Please sign in again.';

  @override
  String get authGoToLogin => 'Go to login';

  @override
  String get profileStudioBillingTitle => 'Billing & Invoicing';

  @override
  String get profileStudioBillingSubtitle =>
      'Auto-issue invoices for instructor payments';

  @override
  String get studioBillingProviderMorning => 'Morning (Green Invoice)';

  @override
  String get studioBillingProviderIcount => 'iCount';

  @override
  String get studioBillingSummaryNotConnected => 'Not connected';

  @override
  String get studioBillingSummaryMorningActive => 'Morning active';

  @override
  String get studioBillingSummaryIcountActive => 'iCount active';

  @override
  String get studioBillingSummaryConnected => 'Connected';

  @override
  String get studioBillingPlatformManagedNotice =>
      'Payments are managed by QuickFit (Rapyd/BitPay). No studio payment setup is required.';

  @override
  String get studioBillingInvoicingSectionTitle => 'Invoicing';

  @override
  String get studioBillingNoProviderConnected => 'No provider connected yet.';

  @override
  String get studioBillingStatusActive => 'Active';

  @override
  String get studioBillingStatusInactive => 'Inactive';

  @override
  String get studioBillingMenuEdit => 'Edit';

  @override
  String get studioBillingMenuSetInactive => 'Set inactive';

  @override
  String get studioBillingMenuSetActive => 'Set active';

  @override
  String get studioBillingMenuRemove => 'Remove';

  @override
  String get studioBillingConnectMorning => 'Connect Morning';

  @override
  String get studioBillingConnectIcount => 'Connect iCount';

  @override
  String get studioBillingBaseUrlRequired => 'Base URL is required';

  @override
  String get studioBillingBaseUrlHttpsRequired =>
      'Base URL must start with https://';

  @override
  String get studioBillingApiTokenRequired => 'API token is required';

  @override
  String get studioBillingApiKeyRequired => 'API key is required';

  @override
  String studioBillingConnected(Object provider) {
    return '$provider connected';
  }

  @override
  String studioBillingConnectProvider(Object provider) {
    return 'Connect $provider';
  }

  @override
  String studioBillingEditProvider(Object provider) {
    return 'Edit $provider';
  }

  @override
  String get studioBillingBaseUrlLabel => 'Base URL';

  @override
  String get studioBillingApiTokenLabel =>
      'API token (leave empty to keep existing)';

  @override
  String get studioBillingApiKeyLabel =>
      'API key (leave empty to keep existing)';

  @override
  String get studioBillingAccountIdOptionalLabel => 'Account ID (optional)';

  @override
  String get studioBillingDefaultVatOptionalLabel =>
      'Default VAT rate (optional)';

  @override
  String get profileStudioPricingTitle => 'Default Pricing';

  @override
  String get profileStudioPricingSubtitle =>
      'Base rate and lead-time surge rules';

  @override
  String get profileStudioPricingDefaultRate => 'Default base rate (ILS)';

  @override
  String get profileStudioPricingRuleHours => 'Window (hours before start)';

  @override
  String get profileStudioPricingRuleBoost => 'Boost (%)';

  @override
  String get profileStudioPricingAddRule => 'Add rule';

  @override
  String get profileStudioPricingSaved => 'Studio pricing updated.';

  @override
  String get profileStudioPricingSaveFailed =>
      'Failed to update studio pricing.';

  @override
  String profileStudioPricingSummary(Object rate, Object rules) {
    return 'ILS $rate, $rules';
  }

  @override
  String profileStudioPricingRuleCompact(Object hours, Object boost) {
    return '${hours}h:+$boost%';
  }

  @override
  String get profileStudioPublicJobsTitle => 'My Available Jobs';

  @override
  String get profileStudioPublicJobsSubtitle =>
      'View public profile with active jobs';

  @override
  String profileStudioActiveJobsCount(Object count) {
    return '$count active';
  }

  @override
  String get studioPublicProfileTitle => 'Studio Profile';

  @override
  String get studioPublicProfileNotFound => 'Studio not found';

  @override
  String get studioPublicProfileFallbackName => 'Studio';

  @override
  String studioPublicProfileOpenJobsCount(Object count) {
    return 'Open jobs: $count';
  }

  @override
  String studioPublicProfileActiveJobsCount(Object count) {
    return 'Active jobs: $count';
  }

  @override
  String get studioPublicProfileAvailableJobsTitle => 'Available Jobs';

  @override
  String get studioPublicProfileNoAvailableJobs =>
      'No available jobs right now.';

  @override
  String get studioPublicProfileUntitledClass => 'Untitled class';

  @override
  String get studioPublicProfileCategoryFallback => 'general';

  @override
  String get studioPublicProfileRateCurrency => 'ILS';

  @override
  String studioPublicProfilePostedAt(Object time) {
    return 'Posted $time';
  }

  @override
  String get jobDetailClaimQueued => 'Claim request queued.';

  @override
  String get jobDetailWithdrawalQueued => 'Withdrawal request queued.';

  @override
  String get jobDetailNoActiveClaim => 'No active claim found.';

  @override
  String get jobDetailClaimRejected => 'Claim rejected.';

  @override
  String jobDetailActionFailed(Object error) {
    return 'Action failed: $error';
  }

  @override
  String get jobDetailCancelled => 'Job cancelled.';

  @override
  String jobDetailCancelFailed(Object error) {
    return 'Failed to cancel: $error';
  }

  @override
  String get jobDetailTitle => 'Job Details';

  @override
  String get jobDetailNotFound => 'Job not found';

  @override
  String get jobDetailSosBoost => 'SOS BOOST';

  @override
  String get jobDetailDefaultTitle => 'Fitness Class';

  @override
  String get jobDetailDefaultStudio => 'Studio';

  @override
  String get jobDetailDate => 'Date';

  @override
  String get jobDetailTime => 'Time';

  @override
  String get jobDetailLocation => 'Location';

  @override
  String get jobDetailDefaultLocation => 'Israel';

  @override
  String get jobDetailRate => 'Rate';

  @override
  String get jobDetailRequirements => 'Requirements & Notes';

  @override
  String get jobDetailNoRequirements => 'No special requirements listed.';

  @override
  String get jobDetailClaimBackup => 'Claim as Backup';

  @override
  String get jobDetailClaimPrimary => 'Claim this Job';

  @override
  String get jobDetailBackupHint =>
      'This job is claimed, but you can join as a backup.';

  @override
  String get jobDetailClaimedBy => 'Claimed By';

  @override
  String get jobDetailRejectClaim => 'Reject Claim';

  @override
  String get jobDetailAcceptClaim => 'Accept Claim';

  @override
  String get jobDetailPrimaryRole => 'You are the primary instructor.';

  @override
  String get jobDetailBackupRole => 'You are an assigned backup.';

  @override
  String get jobDetailProcessing => 'Processing...';

  @override
  String get jobDetailCancelClaim => 'Cancel Claim';

  @override
  String get jobDetailUnknown => 'Unknown';

  @override
  String get jobDetailVerifiedProfessional => 'Verified Professional';

  @override
  String get jobDetailCancelTitle => 'Cancel Job?';

  @override
  String get jobDetailCancelBody =>
      'Are you sure you want to cancel this job? This cannot be undone.';

  @override
  String get jobDetailKeepIt => 'Keep It';

  @override
  String get jobDetailCancelCta => 'Cancel Job';

  @override
  String get jobDetailCompleteSuccessSnack => 'Job marked as completed.';

  @override
  String jobDetailCompleteFailureSnack(Object error) {
    return 'Failed to complete job: $error';
  }

  @override
  String jobDetailRateDialogTitle(Object targetLabel) {
    return 'Rate $targetLabel';
  }

  @override
  String get jobDetailRatePrompt => 'How was your experience?';

  @override
  String get jobDetailRateCommentHint => 'Optional comment';

  @override
  String get jobDetailRatingSubmittedSnack => 'Rating submitted.';

  @override
  String jobDetailRatingFailedSnack(Object error) {
    return 'Failed to submit rating: $error';
  }

  @override
  String get jobDetailRateTargetInstructor => 'instructor';

  @override
  String get jobDetailRateTargetStudio => 'studio';

  @override
  String get jobDetailRateCounterpartCta => 'Rate counterpart';

  @override
  String get onboardingLocationUnavailable =>
      'Could not get your location. Try entering your address.';

  @override
  String get onboardingLocationNotFound =>
      'Could not find location. Please select from the list or use GPS.';

  @override
  String get onboardingStudioLocationRequired =>
      'Studio location required. Please enter a valid address.';

  @override
  String get onboardingSetupFailed =>
      'Failed to complete setup. Please try again.';

  @override
  String get onboardingWelcomeTitle => 'Welcome.';

  @override
  String get onboardingWelcomeBody => 'Choose your role to continue.';

  @override
  String get onboardingRoleInstructor => 'Instructor';

  @override
  String get onboardingRoleInstructorBody =>
      'Find sub jobs at studios near you and grow your network.';

  @override
  String get onboardingRoleStudio => 'Studio';

  @override
  String get onboardingRoleStudioBody =>
      'Post classes and find reliable instructors in minutes.';

  @override
  String get onboardingBuildProfile => 'Build your profile.';

  @override
  String get onboardingFullName => 'Full Name';

  @override
  String get onboardingStudioName => 'Studio Name';

  @override
  String get onboardingAddress => 'Address';

  @override
  String get onboardingAddressHint => 'e.g., Rothschild 1, Tel Aviv';

  @override
  String get onboardingUseCurrentLocation => 'Use Current Location';

  @override
  String get onboardingYourExpertise => 'Your Expertise';

  @override
  String get onboardingCoverageZones => 'Coverage Zones';

  @override
  String get onboardingSearchRadius => 'Search Radius';

  @override
  String get onboardingZoneHint =>
      'Tap zones on the map to select your coverage areas.';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get onboardingNextStep => 'Next Step';

  @override
  String get onboardingTipFastMatchingTitle => 'Fast Matching';

  @override
  String get onboardingTipFastMatchingBody =>
      'Connect with studios in real-time.';

  @override
  String get onboardingTipVerifiedTitle => 'Verified Pros';

  @override
  String get onboardingTipVerifiedBody =>
      'Join a community of certified instructors.';

  @override
  String get onboardingTipLocalTitle => 'Local Focus';

  @override
  String get onboardingTipLocalBody => 'Work exactly where you want to.';

  @override
  String get onboardingPreview => 'PREVIEW';

  @override
  String get onboardingYourName => 'Your Name';

  @override
  String get onboardingUnselected => 'UNSELECTED';

  @override
  String get onboardingSelectCategoriesHint =>
      'Select categories to see them here.';

  @override
  String onboardingRadiusLabel(Object value) {
    return '$value km radius';
  }

  @override
  String get onboardingFindMyLocation => 'Find My Location';

  @override
  String get onboardingCouldNotLoadZones => 'Could not load zones';

  @override
  String get onboardingTryRadiusMode => 'Try radius mode instead';

  @override
  String get onboardingSetYourLocation => 'Set Your Location';

  @override
  String get onboardingSetYourLocationBody =>
      'Enter your address in the form, or use GPS:';

  @override
  String mapRadiusKm(Object value) {
    return '$value km';
  }
}
