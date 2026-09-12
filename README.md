# Video Saver

Android app (`com.ezitech.ezisaver`) that downloads videos from social platforms
and saves them to the phone's gallery. Flutter front end; the extraction runs on
the Laravel backend at `https://ezisaver.ezitech.org/api`.

## How a download works

1. The user pastes a link, or shares a video into the app from another app.
2. `POST /downloads` creates a job; the server runs yt-dlp.
3. The app polls `GET /downloads/{id}` until the job finishes.
4. The finished file is fetched and handed to the gallery via `gal`, into an
   album called **EziDownload**.

## YouTube is not supported, and must not be added

Version 7 was **rejected by Google Play** on 9 September 2026 under the
**Device and Network Abuse policy**:

> Your app accesses or uses a service or API in a manner that violates YouTube
> terms of service.

There is no compliant way to download YouTube content from a Play-distributed
app. Keep it out of the code, the store listing and the screenshots.
`test/platforms_test.dart` has a test that fails if any platform starts
accepting a YouTube link.

## Supported platforms

TikTok, Instagram, Facebook, Twitter / X, Dailymotion, Vimeo.

All of them live in [`lib/platforms.dart`](lib/platforms.dart) — one place for
the brand colours, the hosts, and the URL shapes that can actually hold a video.
Both download screens validate against it, so a feed, profile or login page is
refused on the device instead of becoming a server job that is certain to fail.

## Running it

```bash
flutter pub get
flutter run
```

`android/key.properties` is not in the repository. Without it, release builds
fall back to debug signing; add it (`keyAlias`, `keyPassword`, `storeFile`,
`storePassword`) to produce a signed release.

## Checks

```bash
flutter analyze && flutter test
```

## Known gaps

- The backend never fills in `title` or `thumbnail_url`, so the history screen
  shows the source link and a platform tile instead.
- `quality` is accepted by the API but only ever sent as `1080p`; whether the
  backend supports anything else is unconfirmed.
- `GET /downloads` is unauthenticated and returns every user's downloads, so the
  app deliberately never calls it. History is kept per device.
