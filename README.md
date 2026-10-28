# GM Tailors bill app

This repository contains the existing invoice website and a separate Flutter app:

- `website/` keeps the original site and its image/payment assets.
- `app/` is the Android, iOS, and web Flutter app.

## Run the app

```sh
cd app
flutter pub get
flutter run
```

The app supports English/Tamil interface and invoice labels, adjustable item rows, the GM Tailors invoice layout, PDF preview/download, bill history with edit/delete, manual income entries, and month/week analysis charts. Bills are stored on the device using local preferences, so they work offline but do not sync to another device. Item descriptions and customer names are kept as entered; the language switch translates the interface and invoice labels, not free-text content.

## Security

No Supabase service-role secret or GitHub token is included in the app or repository. This app currently uses local storage; adding cloud sync requires a user sign-in and owner-scoped Row Level Security policies before uploading customer records.

The bundled Noto Sans Tamil font and license are in `app/assets/fonts/`.
