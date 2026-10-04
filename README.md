# Garibook — Route & Car Navigation

[![Flutter](https://img.shields.io/badge/Flutter-3.44.0-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10+-0175C2?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://developer.android.com)

A Flutter vehicle navigation app for the **Senior Mobile Developer Assessment**, featuring custom native Android location bridging, real-time OpenStreetMap rendering, and turn-by-turn routing via OSRM.

## 🛠️ Tech Stack & Versions
- **Flutter:** `3.44.1` (Dart `3.12.1`)
- **flutter_riverpod:** `^3.4.3` (State Management)
- **flutter_map:** `^8.3.2` (Map rendering)
- **latlong2:** `^0.10.1` (Geographical math)
- **http:** `^1.6.0` (Routing API requests)

## 🚀 Getting Started

Clone the repository and install dependencies:
```bash
git clone https://github.com/ShahriarSaem/garibook.git
cd garibook
flutter pub get
```

## 🏗️ How to Run

This project uses build flavors (`dev` and `prod`). Both can be installed side-by-side.

**Run Development Flavor:**
```bash
flutter run --flavor dev -t lib/main.dart
```

**Run Production Flavor:**
```bash
flutter run --flavor prod -t lib/main.dart
```

## ⚠️ Known Limitations
- **Internet Required:** Route calculation relies on a live OSRM server and requires an active internet connection.
- **Emulators:** When testing on an Android emulator, you must manually simulate movement using the emulator's Extended Controls (Location).

## 📄 Decisions & Architecture
For details on architecture, state management (Riverpod), the native location bridge, and math logic, please read:
👉 [**DECISIONS.md**](./DECISIONS.md)
