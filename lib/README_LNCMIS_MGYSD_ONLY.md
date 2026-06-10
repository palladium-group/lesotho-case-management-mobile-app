# LNCMIS MGYSD-only lib cleanup

This lib folder has been reduced to the MGYSD/LNCMIS case management app and shared dependencies required by it.

## Kept
- `main.dart`, `app.dart`
- shared app state required for login, sync, connectivity and MGYSD lists
- shared core components/services/offline providers required by MGYSD
- login, splash, language selection, synchronization, app logs and MGYSD module
- MGYSD modular structure under `modules/mgysd_case_management/`

## Removed / excluded
- DREAMS module files
- OVC module files
- OGAC module files
- Education module files
- PP Prev module files
- app resume routes/components that directly referenced removed modules
- unused old referral components tied to removed modules

## Branding inside lib
- App-facing constants are set to LNCMIS / version 1.0.0 where present in lib.
- Android package changes outside lib still need to be done in Android files:
  - `android/app/build.gradle`
  - `android/app/src/main/AndroidManifest.xml`
  - `android/app/src/main/kotlin/.../MainActivity.kt`
  - optional Gradle namespace if your project uses Android Gradle Plugin 8+

Target package/application id:
`org.palldiumdatafi.lncmis_mobile_app`
