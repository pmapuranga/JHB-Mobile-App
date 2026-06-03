# JHB Sermon Admin

This Laravel app is the administration console for managing sermon content before it is exported to the Flutter mobile app.

## Purpose

- Manage sermon metadata: code, title, preacher, date, place, language, category.
- Manage transcript paragraphs and optional audio timestamp ranges.
- Prepare search text for the mobile app.
- Export a mobile-ready `sermon_library.sqlite` package.

## Local MySQL Setup

Create a MySQL database:

```sql
CREATE DATABASE sermon_admin CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

Set these values in `.env`:

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=sermon_admin
DB_USERNAME=root
DB_PASSWORD=
```

Run migrations:

```bash
php artisan migrate
```

Import the current mobile preload data:

```bash
php artisan sermons:import-mobile
```

Export a mobile SQLite package:

```bash
php artisan sermons:export-mobile
```

The JSON template for clean sermon ingestion is at:

```text
storage/app/templates/sermon-template.json
```

## Recommended Workflow

1. Add or upload source sermon files in the admin console.
2. Review metadata and paragraph split.
3. Add audio filename and timestamp ranges when available.
4. Export `sermon_library.sqlite`.
5. Bundle the exported SQLite file and `.opus` audio files with the mobile app or publish them as a downloadable content package.
