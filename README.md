# JHB Mobile App

JHB Mobile App is a Flutter sermon library for mobile devices. It is built around searchable sermon transcripts, preloaded sermon metadata, synced audio playback, and a Laravel administration console for managing the library.

The app is no longer a PDF book reader. PDF support may still exist in legacy code paths, but the main product direction is sermon-first: list sermons, search sermon text, open a sermon, read the transcript, and play audio from the selected paragraph.

## Main Features

- Mobile sermon listing by date, title, length, book/category, and place.
- Search across all sermons or inside the current sermon.
- Search results open the sermon at the matching paragraph.
- Sermon reader screen with transcript text, paragraph highlighting, and audio controls.
- Tap a paragraph to seek and play audio from that paragraph position.
- Preloaded mobile data using SQLite and JSON assets.
- Offline-ready sermon library package.
- Laravel web administration console backed by MySQL.
- Export workflow from admin data to mobile preload package.

## Mobile Data Structure

The mobile app uses a sermon library package under:

```text
assets/preload/
```

Important files:

```text
assets/preload/books.json
assets/preload/search_index.json
assets/preload/sermon_library.sqlite
assets/preload/sermons/
assets/preload/audios/
```

The SQLite library contains:

```text
sermons
sermon_paragraphs
sermon_search
downloads
bookmarks
highlights
```

Audio files are stored as mobile assets under:

```text
assets/preload/audios/
```

Large audio files are tracked with Git LFS.

## Laravel Admin Console

The administration console lives in:

```text
admin/
```

It is a Laravel web app backed by MySQL. Use it to manage sermons, transcript paragraphs, audio metadata, timestamps, and exports.

Admin capabilities include:

- Create and edit sermons.
- Upload or manage transcript text.
- Add and update paragraph timestamps.
- Manage audio file references.
- Export the mobile preload package.

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

Because the app includes preloaded audio, the APK can be large. On an emulator, make sure there is enough internal storage before installing.

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
- `admin/vendor/`, Flutter build folders, emulator screenshots, and generated build artifacts are ignored.
- Sermon audio assets are committed through Git LFS.
- Raw duplicate source audio under `sources/Audios/` is ignored.

## Project Direction

The goal is to make JHB Mobile App a complete sermon library system:

- Laravel/MySQL admin console as the source of truth.
- Mobile SQLite/asset package exported from the admin console.
- Offline mobile reading and listening.
- Accurate paragraph-to-audio timestamp sync.
- Searchable transcript text with clickable results.
