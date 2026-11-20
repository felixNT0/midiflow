iOS build not included in app-installers.

Fastest way to put MIDIFlow on an iPhone for testing (no paid account):

  1. Connect the iPhone to this Mac with a cable, unlock it, and tap
     "Trust This Computer".
  2. In Xcode → Settings → Accounts, sign in with any Apple ID.
  3. From this project folder run:
       flutter run -d <iphone-device-id>
     (find the id with `flutter devices`)
  4. The app installs and runs for up to 7 days (free provisioning).
     Re-run `flutter run` to renew.

For a shareable build (TestFlight / App Store), a paid Apple Developer
Program membership ($99/yr) is required, then:
  flutter build ipa --release
with signing configured in Xcode or an ExportOptions.plist.

There is also a commented `ios` job in .github/workflows/build.yml that
builds an IPA in CI once signing secrets are configured.
