# Market Glass

A small stock-market application built with **DartNative**. It downloads real
daily market data, updates the screen with `StatefulWidget`, and draws a
price chart with up to 30 sessions without adding an HTTP, JSON,
state-management, or chart package.

The project is intentionally written as a beginner-friendly example for people
who have never used DartNative.

## What is DartNative?

DartNative is a UI framework for building native applications in Dart. Its
widget API is familiar if you have seen Flutter, but this project is a
**DartNative application, not a Flutter application**.

The distinction is important:

- UI widgets come from `package:dartnative/dartnative.dart`.
- Dart standard libraries such as `dart:io`, `dart:convert`, and `dart:async`
  can be used directly.
- Pure-Dart packages and DartNative plugins can be added when needed.
- Flutter-only plugins should not be assumed to work in a DartNative app.
- DartNative projects use the `dn` command for dependency resolution, running,
  and building.

This application does not need an extra package for networking because the Dart
runtime already provides an HTTP client. It does not need a JSON package because
the Dart SDK already includes a JSON decoder.

## What the demo includes

- Live daily data for Apple, Microsoft, and NVIDIA
- Symbol switching and manual refresh
- Latest close, daily change, range, open, and volume
- A chart of up to 30 sessions drawn with DartNative's standard `CustomPainter`
- Loading, error, and retry states
- A native large-title navigation bar
- Native Liquid Glass controls on iOS 26+

## Project layout

```text
lib/
  main.dart                         App, networking, models, and UI
  dartnative_plugin_registrant.dart Platform/plugin registration
ios/                                Native iOS runner
android/                            Native Android runner
pubspec.yaml                        DartNative dependencies and assets
```

Everything specific to this demonstration is kept in `lib/main.dart` so the
complete data flow is easy to follow.

## Prerequisites

Before running the project, you need:

- A DartNative SDK installation with the `dn` command available
- A DartNative license
- Xcode and an iOS Simulator for iOS development
- Android Studio/Android SDK and an emulator for Android development

Confirm that the command is available:

```sh
dn --version
dn doctor
```

## Configure the DartNative license

DartNative applications require a license. Subscribe from the
[DartNative Framework page](https://dartpub.dev/framework), copy the license key
from the Framework panel, and configure it once:

```sh
dn config --license-key dnk_your_key_here
```

If you do not want to save the key on the machine, pass it only for the current
run:

```sh
dn run --dart-define=DN_LICENSE_KEY=dnk_your_key_here
```

Never commit a real license key to this repository.

## Install project dependencies

From the repository root, run:

```sh
dn pub get
```

The dependencies in `pubspec.yaml` provide the DartNative framework and its iOS,
Android, and drawing backends. No third-party networking dependency is used.

Use `dn pub get`, not `flutter pub get`, for this project.

## Run the application

List the available devices and simulators:

```sh
dn devices
dn emulators
```

Start an emulator if necessary, then run the app by device ID or name:

```sh
dn run -d <device-id>
```

For example:

```sh
dn run -d "iPhone 17 Pro"
```

If only one compatible device is available, this is usually enough:

```sh
dn run
```

## Build for iOS

Create a debug build for the iOS Simulator:

```sh
dn build ios --debug --simulator --no-codesign
```

The generated app is placed at:

```text
build/ios/iphonesimulator/Runner.app
```

Create a release build for a physical iOS device with:

```sh
dn build ios --release
```

A physical-device or distribution build requires the appropriate Apple signing
configuration in Xcode.

## How API access works without an HTTP package

The application imports two Dart standard libraries:

```dart
import 'dart:convert';
import 'dart:io';
```

`dart:io` supplies `HttpClient`. `dart:convert` supplies `jsonDecode` and the
UTF-8 decoder. They are part of the Dart SDK, so nothing needs to be added to
`pubspec.yaml`.

The complete request flow is:

```text
User selects a symbol
        ↓
StockPriceApi.fetchDaily(symbol)
        ↓
HttpClient sends an HTTPS GET request
        ↓
The response byte stream is decoded as UTF-8
        ↓
jsonDecode converts the JSON string to Dart maps and lists
        ↓
The response arrays are converted to PricePoint objects
        ↓
setState updates the screen
        ↓
Widgets and CustomPainter render the new values
```

### 1. Construct the URL

The demo requests one month of daily chart data:

```dart
final uri = Uri.https(
  'query1.finance.yahoo.com',
  '/v8/finance/chart/$ticker',
  {
    'range': '1mo',
    'interval': '1d',
    'events': 'history',
  },
);
```

Using `Uri.https` handles query-string escaping and guarantees an HTTPS URL.

### 2. Send the request

The request uses the standard `HttpClient` and defines connection/response
timeouts so the UI does not wait forever on a failed connection:

```dart
final client = HttpClient()
  ..connectionTimeout = const Duration(seconds: 10);

final request = await client.getUrl(uri);
request.headers.set(HttpHeaders.acceptHeader, 'application/json');
request.headers.set(HttpHeaders.userAgentHeader, 'MarketGlass/1.0');

final response = await request.close().timeout(
  const Duration(seconds: 12),
);
```

The response status is checked before parsing:

```dart
if (response.statusCode != HttpStatus.ok) {
  throw Exception('API returned HTTP ${response.statusCode}');
}
```

### 3. Decode the response

An HTTP response is a stream of bytes. The bytes are first decoded as UTF-8,
then the resulting string is parsed as JSON:

```dart
final body = await response.transform(utf8.decoder).join();
final root = jsonDecode(body) as Map<String, dynamic>;
```

The API returns timestamps and OHLCV values in parallel arrays. The demo walks
those arrays and creates a typed `PricePoint` for each valid session:

```dart
result.add(
  PricePoint(
    date: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
    open: open,
    high: high,
    low: low,
    close: close,
    volume: volume,
  ),
);
```

OHLCV means open, high, low, close, and volume.

### 4. Close the client

The client is closed in `finally`, including when a request or parsing operation
throws an exception:

```dart
try {
  // Request and parse data.
} finally {
  client.close(force: true);
}
```

### 5. Update the UI

`MarketScreen` is a `StatefulWidget`. It starts the request in `initState` and
calls `setState` after the asynchronous work completes:

```dart
@override
void initState() {
  super.initState();
  loadPrices();
}

final result = await StockPriceApi.fetchDaily(symbol);
if (!mounted) return;

setState(() {
  prices = result;
  loading = false;
});
```

The `mounted` check matters: a network request may finish after the user has
already left the screen. Calling `setState` on a removed screen would be invalid.

The `loading`, `error`, and `prices` fields determine which UI is rendered:

- Loading message while the first request is running
- Retry state when the request fails
- Price, statistics, and chart when data is available

## How the chart works without a chart package

`PriceChartPainter` extends DartNative's `CustomPainter`. It finds the minimum
and maximum closing prices, maps every value into the available canvas size, and
connects the resulting points with a `Path`:

```dart
final x = xPadding + chartWidth * index / (values.length - 1);
final y = yPadding + (maximum - values[index]) / span * chartHeight;

path.lineTo(x, y);
canvas.drawPath(path, linePaint);
```

This is sufficient for a small line chart. A dedicated chart package would be
useful for advanced axes, gestures, accessibility, annotations, or multiple data
series, but it is not required for this demonstration.

## Liquid Glass on iOS

The app uses DartNative's `GlassEffectContainer`, `GlassEffectGroup`, and native
`AppBar` APIs. On iOS 26+, these are backed by the native `UIGlassEffect`, rather
than a painted imitation of glass.

```dart
GlassEffectContainer(
  interactive: true,
  borderRadius: BorderRadius.circular(18),
  child: symbolButton,
)
```

`interactive: true` enables the system touch response. The glass effect is an
iOS 26 feature; DartNative keeps the child content usable on older iOS versions
and Android, while the app's colors and borders provide a readable fallback.

The large navigation title is also controlled by the native app bar and
collapses as the primary scroll view moves.

## Error handling used in this demo

The networking layer accounts for:

- Connection and response timeouts
- Non-200 HTTP responses
- API-level errors
- Empty results
- Missing/null trading sessions
- Requests completing after the screen is disposed

The UI catches these errors and displays a retry action. Existing data remains
on screen when a refresh fails.

## Market-data notice

This project uses Yahoo Finance's public chart endpoint for demonstration
purposes. It does not require an API key, but it is not presented here as a
contracted or guaranteed market-data service. Availability, response shape,
rate limits, and usage terms may change.

For a production application:

- Use a market-data provider whose license and service level fit your product.
- Keep secret API keys on a backend, not inside the mobile application.
- Validate API responses defensively.
- Add caching and retry/backoff behavior.
- Clearly identify delayed data when applicable.

This application is a technical demonstration and is not investment advice.

## Adding packages later

Packages are optional, not forbidden. Browse [dartpub.dev](https://dartpub.dev)
for DartNative plugins and compatible Pure-Dart packages. After adding a
dependency to `pubspec.yaml`, resolve it with:

```sh
dn pub get
```

Check that a package is Pure Dart or explicitly supports DartNative. A package
that depends on the Flutter engine or Flutter's platform-plugin APIs is not
automatically compatible.

## Useful commands

```sh
dn doctor
dn devices
dn pub get
dn analyze
dn run -d <device-id>
dn build ios --debug --simulator --no-codesign
```

Use `dn` for DartNative project operations rather than the Flutter CLI.

## Native runner files

The following files are part of the DartNative platform runner and should not be
changed unless you understand the runtime integration:

- `ios/Runner/AppDelegate.swift`
- `ios/Runner/SceneDelegate.swift`
- The scene configuration in `ios/Runner/Info.plist`
- `android/.../Application.kt`
- `android/.../MainActivity.kt`
- Material 3 themes in `android/app/src/main/res/values*/styles.xml`

These files initialize the native hosts that render the DartNative widget tree.
