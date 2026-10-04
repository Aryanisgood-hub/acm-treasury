/// Single source of truth for what each role may see/do IN THE UI.
/// The database (RLS + triggers) enforces the same rules independently.
enum AppRole {
  president('president', 'President'),
  vicePresident('vice_president', 'Vice President'),
  facultyCoordinator('faculty_coordinator', 'Faculty Coordinator'),
  treasurer('treasurer', 'Treasurer');

  const AppRole(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static AppRole? fromDb(String? value) {
    for (final r in AppRole.values) {
      if (r.dbValue == value) return r;
    }
    return null;
  }

  bool get canAddBill => this == treasurer;
  bool get canEditBill => true;
  bool get canVoidBill => true;
  bool get canManageEvents => true;
  bool get canRequestBudgetChange => this == treasurer;
  bool get canReviewBudget => this == president;
}
