# News & Event App

A Flutter mobile application for viewing and managing news articles and events with role-based access control.

## Project Structure

The project follows clean architecture principles:

```
lib/
├── config/              # Configuration files (Supabase, environment)
├── data/                # Data layer
│   ├── datasources/     # Remote and local data sources
│   ├── models/          # Data models with JSON serialization
│   └── repositories/    # Repository implementations
├── domain/              # Domain layer
│   ├── entities/        # Business entities
│   └── repositories/    # Repository interfaces
└── presentation/        # Presentation layer
    ├── providers/       # State management (Provider)
    ├── screens/         # UI screens
    └── widgets/         # Reusable widgets
```

## Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Configure Supabase

1. Copy `.env.example` to `assets/.env`
2. Fill in your Supabase credentials:
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_ANON_KEY`: Your Supabase anonymous key

### 3. Run the App

```bash
flutter run
```

## Dependencies

- **supabase_flutter**: Backend and authentication
- **provider**: State management
- **cached_network_image**: Image caching
- **image_picker**: Image selection
- **intl**: Internationalization and date formatting
- **flutter_secure_storage**: Secure token storage

## Features

- User registration and authentication
- Role-based access control (User/Admin)
- News article viewing and management
- Event viewing and management
- Image upload support
- Pull-to-refresh functionality

## Requirements

- Flutter SDK 3.9.2 or higher
- Dart SDK 3.0 or higher
- iOS 12.0+ / Android 5.0+
