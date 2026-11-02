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

The app supports English/Tamil interface and invoice labels, adjustable item rows, the GM Tailors invoice layout, PDF preview/download, bill history with edit/delete, manual income entries, and month/week analysis charts. Bills are cached on the device and synced to the shared Supabase bill list, including realtime updates across app installs. Existing local bills are migrated the first time each install connects.

## Security

The app includes only the Supabase publishable key. The shared bill table intentionally allows anonymous read/write access to match the no-sign-in shared-data requirement. That means any app install or client using the public key can read, add, edit, and delete all customer bills; do not use this access model if the records must be private.

The production schema is in `supabase/migrations/20261102090000_create_public_shared_bills.sql`.

The bundled Noto Sans Tamil font and license are in `app/assets/fonts/`.
