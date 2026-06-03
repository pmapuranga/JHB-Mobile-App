# JHB Mobile App

JHB Mobile App is a Flutter-based mobile sermon library with searchable transcripts, synced audio playback, offline preload data, and a Laravel administration console for managing sermon content.

This project is no longer a PDF book reader. The current direction is sermon-first: users browse sermons, search transcript text, open a sermon, read the structured transcript, and play audio from the selected paragraph.

## Overview

The system has two main parts:

- **Mobile app**: Flutter application for offline sermon reading, searching, and audio playback.
- **Admin console**: Laravel web application backed by MySQL for managing sermons, transcripts, audio metadata, timestamps, and mobile exports.

The admin console is intended to become the source of truth. It exports a mobile-ready package that the Flutter app can preload and use offline.

## Features

- Sermon listing by date, title, length, category/book, and place.
- Search across all sermons or inside the current sermon.
- Clickable search results that open the sermon at the matching paragraph.
- Sermon reader screen with structured transcript text.
- Paragraph highlighting while reading or playing audio.
- Tap a paragraph to seek and play audio from that paragraph position.
- Preloaded mobile sermon data using SQLite and JSON assets.
- Offline sermon access after the app is installed.
- Laravel/MySQL admin console for managing sermon records.
- Mobile export workflow from admin data to Flutter preload files.

## Architecture

```text
Laravel Admin Console
        |
        | manages sermons, transcripts, audio, timestamps
        v
MySQL Database
        |
        | export command
        v
Mobile Preload Package
        |
        | bundled with Flutter assets
        v
JHB Mobile App
```

## Mobile Data Package

The mobile preload package lives under:

```text
assets/preload/
```

Important files and folders:

```text
assets/preload/books.json
assets/preload/search_index.json
assets/preload/sermon_library.sqlite
assets/preload/sermons/
assets/preload/audios/
```

The Flutter app uses these files to show the sermon list, search transcript text, open sermons, and play audio offline.

## Mobile SQLite Structure

The mobile SQLite package contains:

```text
sermons
sermon_paragraphs
sermon_search
downloads
bookmarks
highlights
```

Main table purpose:

- `sermons`: sermon metadata such as title, preacher, date, place, language, category, audio file, duration, and mobile book id.
- `sermon_paragraphs`: transcript paragraphs linked to sermons, including paragraph numbers and optional audio timestamps.
- `sermon_search`: searchable transcript index used by the mobile search screen.
- `downloads`: future support for downloaded audio tracking.
- `bookmarks`: saved sermon or paragraph bookmarks.
- `highlights`: saved text highlights.

## Audio

Audio files are stored as mobile assets under:

```text
assets/preload/audios/
```

Large audio files are tracked with Git LFS. Make sure Git LFS is installed before cloning or pulling the project:

```powershell
git lfs install
git lfs pull
```

Because audio is bundled into the app, Android APK builds can be large. Emulators need enough internal storage before installing the app.

## Admin Console

The Laravel admin console lives in:

```text
admin/
```

It is used to manage the sermon system:

- Create and edit sermons.
- Upload or manage transcript text.
- Add and update paragraph timestamps.
- Manage audio file references.
- Export the mobile preload package.

The admin console is backed by MySQL. Its `.env` file is ignored and must be configured locally.

## Admin Workflow

Typical content workflow:

1. Add or update a sermon in the Laravel admin console.
2. Add transcript paragraphs.
3. Add audio file metadata or upload audio.
4. Add paragraph timestamp mappings where available.
5. Export the mobile package.
6. Rebuild or reinstall the Flutter app so the updated assets are included.

Mobile export command:

```powershell
cd admin
C:\php85\php.exe artisan sermons:export-mobile
```

The export updates:

```text
assets/preload/sermon_library.sqlite
assets/preload/books.json
assets/preload/search_index.json
```

## Requirements

For the Flutter mobile app:

- Flutter SDK
- Dart SDK
- Android Studio or Android SDK tools
- Android emulator or physical Android device
- Git LFS for sermon audio assets

For the Laravel admin console:

- PHP
- Composer
- MySQL
- Node.js/npm if frontend assets need to be rebuilt

## Running the Flutter App

Install dependencies:

```powershell
flutter pub get
```

Run on an Android emulator:

```powershell
flutter run
```

Build a debug APK:

```powershell
flutter build apk --debug
```

If the emulator appears stuck on the splash screen, wait a little longer on first launch. Large bundled assets can take time to extract and initialize.

## Running the Admin Console

Install PHP dependencies:

```powershell
cd admin
composer install
```

Configure MySQL in:

```text
admin/.env
```

Run migrations:

```powershell
C:\php85\php.exe artisan migrate
```

Start the admin server:

```powershell
C:\php85\php.exe artisan serve --host=127.0.0.1 --port=8080
```

Open:

```text
http://127.0.0.1:8080
```

## Repository Notes

- `admin/.env` is ignored and should not be committed.
- `admin/vendor/` is ignored.
- Flutter build folders are ignored.
- Emulator screenshots and generated build artifacts are ignored.
- Sermon audio assets are tracked through Git LFS.
- Raw duplicate source audio under `sources/Audios/` is ignored.

## Known Limitations

- APK size can be large because sermon audio is bundled.
- iOS simulator testing requires macOS and Xcode.
- Some legacy PDF-reader code still exists but is not the main product direction.
- Accurate tap-to-audio playback depends on paragraph timestamp data being available.

## Project Direction

The goal is to make JHB Mobile App a complete sermon library system:

- Laravel/MySQL admin console as the source of truth.
- Mobile SQLite/asset package exported from the admin console.
- Offline mobile reading and listening.
- Accurate paragraph-to-audio timestamp sync.
- Searchable transcript text with clickable results.
- Future support for bookmarks, highlights, notes, and managed audio downloads.

## Ownership

This repository is for the JHB Mobile App sermon library project.
