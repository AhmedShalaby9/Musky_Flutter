# Musky

Flutter desktop application for stock and client management. Includes Windows, macOS, and Linux runners and a starter welcome screen. Business functionality will be added after requirements are defined.

## Run

Install Flutter and the desktop toolchain for your operating system. Windows requires Visual Studio with the Desktop development with C++ workload.

```sh
flutter pub get
flutter run -d windows
```

Use `-d macos` or `-d linux` on those operating systems.

## Verify

```sh
dart analyze lib test
flutter test
```

Backend: https://github.com/AhmedShalaby9/Musky_backend
