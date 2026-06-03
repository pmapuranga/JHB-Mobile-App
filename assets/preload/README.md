# Preloaded PDF Library

Place PDFs that should ship with the mobile app in:

`assets/preload/pdfs/`

Then register them in `assets/preload/books.json`:

```json
{
  "version": 2,
  "books": [
    {
      "id": "book-001",
      "title": "My First PDF",
      "asset": "assets/preload/pdfs/my-first-pdf.pdf",
      "idCode": "001",
      "location": "Preloaded",
      "duration": "TIME: 0:00"
    }
  ]
}
```

Increase `version` when you add more bundled books. The app imports new records
from this local database on startup without removing user-added books.
