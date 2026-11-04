/// `money-tracker_2026-11-01_2026-11-30.csv`: the period is in the name. For an export of all
/// data the caller passes the dates of the first and last transaction.
func exportFileName(from: CivilDate, to: CivilDate, fileExtension: String) -> String {
    "\(exportFilePrefix)\(from)_\(to).\(fileExtension)"
}

/// Prefix shared by every file the export writes, so leftovers can be found.
let exportFilePrefix = "money-tracker_"
