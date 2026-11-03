import 'outbox_item.dart';

/// What to do with the outbox when a record is written locally
/// (SYNC_PROTOCOL §6, step 3).
sealed class OutboxWriteDecision {
  const OutboxWriteDecision();
}

/// Overwrite the not-yet-sent entry [seq] (rule 3.1).
class ReplaceEntry extends OutboxWriteDecision {
  const ReplaceEntry(this.seq);

  final int seq;
}

/// Add a new entry (rule 3.3).
class AppendEntry extends OutboxWriteDecision {
  const AppendEntry();
}

/// A delete of a record the server never received (rule 3.2): remove the
/// unsent entry [removeSeq] (if any) and delete the local row for good.
class DropRecord extends OutboxWriteDecision {
  const DropRecord(this.removeSeq);

  final int? removeSeq;
}

/// [existing] are the outbox entries of this one record. [serverVersion] is
/// the local row's `server_version` (null when the server never confirmed it).
OutboxWriteDecision decideOutboxWrite({
  required List<OutboxItem> existing,
  required String op,
  required int? serverVersion,
}) {
  OutboxItem? unsent;
  var anyInFlight = false;
  for (final item in existing) {
    if (item.inFlight) {
      anyInFlight = true;
    } else if (unsent == null || item.seq > unsent.seq) {
      unsent = item;
    }
  }
  if (op == 'delete' && serverVersion == null && !anyInFlight) {
    return DropRecord(unsent?.seq);
  }
  if (unsent != null) {
    return ReplaceEntry(unsent.seq);
  }
  return const AppendEntry();
}
