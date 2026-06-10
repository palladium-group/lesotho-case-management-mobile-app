
# MGYSD Case Management Module - Modular Structure

This ZIP reorganizes the MGYSD module into workflow-based submodules so multiple developers can work safely without editing the same large files.

## Folder Structure

```text
mgysd_case_management/
├── shared/                    Common constants, models, helpers, widgets, repositories and services
├── case_shell/                Case list, case detail, dashboard/navigation shell
├── enrollment/                Reported case, intake, initial risk and household enrollment
├── social_investigation/      Social investigation form, rules and skip logic
├── care_plan/                 Care plan, goals and intervention cycle logic
├── service_provision/         Household/member services against goals
├── monitoring/                Routine monitoring and reassessment workflow
├── referral/                  Household/member referrals
└── workflow/                  Repeatable stage list and workflow helpers
```

## Main Design Rule

Pages should gradually become UI-only. Business logic should move into `rules/`, `skip_logic/`, `services/`, and `repositories/`.

## Current Refactor Status

- Files have been moved into business submodules.
- Package imports inside the MGYSD module were updated.
- Initial `rules/` and `skip_logic/` files were added as starting points.
- Existing page logic is intentionally preserved to reduce risk.

## Next Refactor Step

Move heavy page methods into services/repositories:

- `createCarePlanForSocialInvestigation()` -> `care_plan/services/`
- `getActiveCarePlan()` -> `care_plan/repositories/`
- `copyUnresolvedGoals()` -> `monitoring/services/`
- `propagateHouseholdService()` -> `service_provision/services/`
- `loadHouseholdMembers()` -> `shared/repositories/`

## Important Developer Rules

1. Do not hard-code DHIS2 UIDs outside `shared/constants/mgysd_dhis2_uids.dart`.
2. Do not create Care Plans directly from Case Details.
3. One Social Investigation must have one Care Plan.
4. Reassessment creates a new Social Investigation and new Care Plan.
5. Do not save empty forms/events.
6. Always preserve `householdTei`, `memberTei`, `parentCaseId`, `rootCaseId`, and `stageKey` where applicable.
