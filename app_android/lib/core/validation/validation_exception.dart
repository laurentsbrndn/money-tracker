import '../../l10n/generated/app_localizations.dart';

/// A client-side check from BUSINESS_RULES §6 failed. The server repeats the
/// same checks on push, so these only spare the user a round trip.
enum ValidationError {
  nameRequired,
  nameTooLong,
  nameTaken,
  amountRequired,
  amountZero,
  amountRange,
  noteTooLong,
  sourceTooLong,
  dateFuture,
  dateBeforeOpening,
  openingDateFuture,
  accountRequired,
  toAccountRequired,
  sameAccount,
  categoryRequired,
  allocationRequired,
}

class ValidationException implements Exception {
  const ValidationException(this.error);

  final ValidationError error;

  String message(AppLocalizations l10n) => switch (error) {
    ValidationError.nameRequired => l10n.validationNameRequired,
    ValidationError.nameTooLong => l10n.validationNameTooLong,
    ValidationError.nameTaken => l10n.validationNameTaken,
    ValidationError.amountRequired => l10n.validationAmountRequired,
    ValidationError.amountZero => l10n.validationAmountZero,
    ValidationError.amountRange => l10n.validationAmountRange,
    ValidationError.noteTooLong => l10n.validationNoteTooLong,
    ValidationError.sourceTooLong => l10n.validationSourceTooLong,
    ValidationError.dateFuture => l10n.validationDateFuture,
    ValidationError.dateBeforeOpening => l10n.validationDateBeforeOpening,
    ValidationError.openingDateFuture => l10n.validationOpeningDateFuture,
    ValidationError.accountRequired => l10n.validationAccountRequired,
    ValidationError.toAccountRequired => l10n.validationToAccountRequired,
    ValidationError.sameAccount => l10n.validationSameAccount,
    ValidationError.categoryRequired => l10n.validationCategoryRequired,
    ValidationError.allocationRequired => l10n.validationAllocationRequired,
  };
}

/// Thrown when deleting a record that is still referenced; it can only be
/// archived (BUSINESS_RULES §6).
class RecordInUseException implements Exception {
  const RecordInUseException({required this.isAccount});

  final bool isAccount;
}

/// |amount| limit of BUSINESS_RULES §6.
const int maxAmount = 999999999999;
