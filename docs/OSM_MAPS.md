# Map display restored to Google Maps

The OpenStreetMap map display was undone at the user's request. Mobile maps now
use `google_maps_flutter` again, including native map pins and map diagnostics.
GPS validation, automatic dashboard location, saved addresses and delivery-sharing
lifecycle fixes remain. The deployed backend still uses Photon and OSRM for address
lookup and routes; it does not need redeployment for this display change.

Google Maps display requires an Android Maps SDK key. Supply it with
`--dart-define=GOOGLE_MAPS_API_KEY=YOUR_ANDROID_MAPS_KEY`, `android/local.properties`,
a Gradle property or the build environment. Blank values are ignored. When no
explicit key is supplied, Gradle uses the Android client key in
`android/app/google-services.json` whose package matches the app's application ID.
It never reads the backend's server key. The resolved key is placed in the native
Android manifest; restart with a newly built APK after changing it.

The client key must allow Maps SDK for Android in its Google Cloud project, with
billing enabled and Android restrictions matching the package and signing SHA-1.
The debug map's **Map help** button shows the installed package and SHA-1 without
displaying the key. A configured key alone does not confirm Maps authorization.
See [Google's Android setup guide](https://developers.google.com/maps/documentation/android-sdk/start).

```powershell
flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_ANDROID_MAPS_KEY
```

### Blank map verification (16 October 2026)

The debug APK builds and includes the matching Android client key. A map-only
emulator check initializes Google's native map and controls, but the SDK reports
`Authorization failure`. Cloud authorization still needs correction before tiles
can load; this is separate from GPS or the Render backend.

In project `movetraq-1706f`:

1. [Enable Maps SDK for Android](https://console.cloud.google.com/apis/library/maps-android-backend.googleapis.com?project=movetraq-1706f)
   and verify that the project has active billing.
2. In [Credentials](https://console.cloud.google.com/apis/credentials?project=movetraq-1706f),
   allow Maps SDK for Android on the Android client key. Its Android application
   restrictions must include package `com.example.movetraq` and this debug signing
   SHA-1: `07:6E:8E:3A:7D:0A:99:C0:52:9B:16:56:5A:84:EF:53:C1:63:4C:85`.
3. Reopen the map after the settings propagate. If replacing the key instead,
   supply an Android Maps key through one of the build settings above and rebuild.

Use the installed build's **Map help** values for other signing certificates.
The seven map tests pass; the temporary smoke app is not part of the normal app.

The following records the previous OSM implementation and provider setup. Its
`MAP_TILE_*` mobile build flags are no longer used by the restored Google map views.

## Previous OSM implementation

Mobile maps use `flutter_map` and OpenStreetMap tiles. Google Maps SDK and its
Android key/diagnostic channel have been removed. Firebase remains configured
for its existing features.

Run the app with `flutter run`; no maps key is needed. The default legacy API
is still `https://movetraq-api.onrender.com`. Deploy the changed `backend/` and
`server/` applications before checking hosted address search, routing or tracking.

The backend defaults to:

```dotenv
MAPS_PROVIDER=osm
GEOCODER_PROVIDER=photon
PHOTON_URL=https://photon.komoot.io
OSRM_URL=https://router.project-osrm.org
NOMINATIM_URL=https://nominatim.openstreetmap.org
MAPS_USER_AGENT=MoveTraq/1.0 (https://github.com/NdoulaPhilip/Movetraq)
```

The Render deployment uses Photon for geocoding because search and reverse lookup
through public Nominatim returned errors from the Render service during release
verification. Routing remains OSRM. `GEOCODER_PROVIDER=nominatim` is available for
a suitable Nominatim endpoint. Both geocoders use the same queued, cached request
client and preserve the selected point during reverse lookup. Photon's public
demo also has reasonable-use limits and no availability guarantee; configure an
appropriate hosted or self-hosted endpoint for production volume.

The shared `MONITORING_SERVICE_TOKEN` and `DELIVERER_AUTHORITY_URL` bridge setup
in [Go Online](GO_ONLINE.md) still applies. Existing migrations `0015` and `0016`
are reused; no new SQL or duplicate Auth identities are needed for this switch.
The optional `MAPS_PROVIDER=google` backend adapter remains available for existing
integrations, but is not used by the default configuration.

Public tiles, Nominatim and the OSRM demo are evaluation defaults with usage
limits and no delivery-service availability guarantee. For a live marketplace,
configure suitable hosted providers or self-host the services. An open-source
map engine removes the Google billing dependency; it does not provide unlimited
free infrastructure.

Nominatim searches run only when the user presses Search. The backend identifies
itself, serializes requests at least 1.1 seconds apart and caches up to 300 results
for one hour. Public Nominatim usage must stay below one request per second across
the entire application. Multiple backend instances require a shared limiter/cache
or a provider with appropriate capacity. No bulk geocoding is implemented.

The native tile provider uses flutter_map's built-in cache. Visible copyright
attribution and its link remain on each map. Custom tile services can be configured
at build time:

```powershell
flutter run --dart-define=MAP_TILE_URL=https://tiles.example.com/{z}/{x}/{y}.png --dart-define="MAP_TILE_ATTRIBUTION=Your provider / © OpenStreetMap contributors" --dart-define=MAP_TILE_ATTRIBUTION_URL=https://www.openstreetmap.org/copyright
```

After login, sender and driver dashboards request a current GPS point, display it
and save the latest account location through the existing authenticated API.
Denied permission leaves login and manual address selection usable. GPS coordinates
remain visible if reverse lookup is unavailable; failed persistence is shown as a
sync error. The home refresh action retries location, and the driver panel includes
retry and location settings actions.

Delivery sharing is a separate switch. It verifies the approved assigned driver
and active delivery before requesting GPS, rejects stale/mock/invalid samples,
throttles publishing to once per ten seconds and cancels on sign-out, screen disposal
or backgrounding. In-flight requests cannot be recalled, but cancellation prevents
subsequent writes. Returning to the app requires enabling sharing again. Sender
tracking polls the authorized delivery endpoint every five seconds. This is
foreground tracking; background services and Realtime subscriptions are not added.

Check on a real phone: GPS permission accepted/denied, disabled GPS, map pan/zoom,
pin tap/drag and reverse lookup, saved pickup, route distance/ETA, driver sharing,
customer tracking, and stopping sharing on logout/background/completion. Local
widget and provider tests use isolated fixtures rather than public map services.

References: [flutter_map](https://docs.fleaflet.dev/),
[OSM tile policy](https://operations.osmfoundation.org/policies/tiles/),
[Nominatim policy](https://operations.osmfoundation.org/policies/nominatim/),
[OSRM API](https://project-osrm.org/docs/v5.24.0/api/).
[Photon](https://github.com/komoot/photon).
