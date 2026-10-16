# Maps and GPS without Google billing

Mobile maps use `flutter_map` and OpenStreetMap tiles. Google Maps SDK and its
Android key/diagnostic channel have been removed. Firebase remains configured
for its existing features.

Run the app with `flutter run`; no maps key is needed. The default legacy API
is still `https://movetraq-api.onrender.com`. Deploy the changed `backend/` and
`server/` applications before checking hosted address search, routing or tracking.

The backend defaults to:

```dotenv
MAPS_PROVIDER=osm
OSRM_URL=https://router.project-osrm.org
NOMINATIM_URL=https://nominatim.openstreetmap.org
MAPS_USER_AGENT=MoveTraq/1.0 (https://github.com/NdoulaPhilip/Movetraq)
```

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
