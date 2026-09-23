# MoveTraq Flutter UI

A connected Flutter implementation of the supplied MoveTraq design, covering the sender and deliverer journeys.

## Run

Start the Node API:

```bash
cd server
npm start
```

To persist API data in MongoDB, copy `server/.env.example` to `server/.env` and set:

```bash
MONGODB_URI=mongodb://127.0.0.1:27017
MONGODB_DB=movetraq
```

You can also use a MongoDB Atlas connection string for `MONGODB_URI`. If no Mongo URI is configured, the API keeps data in memory only and resets when the server restarts.

## Deploy API on Render

The repository includes `render.yaml` for a Render Web Service. Push the project to GitHub, then in Render choose **New +** > **Blueprint** and select this repository.

Render will use:

```bash
Root Directory: server
Build Command: npm ci
Start Command: npm start
Health Check Path: /health
```

Set `MONGODB_URI` in Render to your MongoDB Atlas connection string, for example:

```bash
mongodb+srv://USER:PASSWORD@CLUSTER.mongodb.net/?retryWrites=true&w=majority
```

After deploy, test the hosted API:

```bash
https://YOUR-SERVICE.onrender.com/health
```

Run the Flutter app against the hosted API:

```bash
flutter run --dart-define=MOVETRAQ_API_URL=https://YOUR-SERVICE.onrender.com
```

Then run the Flutter app from the repository root:

```bash
flutter pub get
flutter run
```

The Flutter app uses the Node API for authentication, profiles, deliveries, courier offers, live locations, chat, notifications, and wallet transaction records. By default it calls `http://10.0.2.2:3000`, which is the Android emulator address for your PC. Override this with:

```bash
flutter run --dart-define=MOVETRAQ_API_URL=http://YOUR_API_HOST:3000
```

For the Android emulator, use the special host address that points back to your PC:

```bash
flutter run --dart-define=MOVETRAQ_API_URL=http://10.0.2.2:3000
```

For a physical phone, use your PC's LAN IP address instead, for example:

```bash
flutter run --dart-define=MOVETRAQ_API_URL=http://192.168.1.20:3000
```

## Main flows

- Onboarding, sign in, and account creation
- Sender home, activity, orders, notifications, profile
- Send parcel, choose/filter deliverers, negotiate, confirm, success
- Tracking list, order details, animated live tracking, chat
- Escrow release, OTP authorization, release success
- Wallet and top-up
- Deliverer jobs, job details, active trip stages, trips, and earnings
