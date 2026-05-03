# Zahlivery Web

This is a separate customer-facing PWA that does not modify the Flutter app.

## What it does

- Works in iPhone Safari and other mobile browsers
- Can be added to the home screen like an app
- Opens in standalone app mode when saved as a Chrome shortcut or Safari home-screen app
- Shows shops, hotels, and service businesses
- Lets customers build a cart and order via WhatsApp or phone call
- Can read live Firebase business/menu data if web config is added

## Files

- `index.html`: app shell
- `styles.css`: responsive UI
- `app.js`: catalog, cart, Firebase loading, and checkout behavior
- `firebase-config.js`: active local config file
- `firebase-config.example.js`: template for live Firebase connection
- `manifest.webmanifest`: install metadata
- `sw.js`: offline caching
- `vercel.json`: Vercel static hosting config

## Deploy on Vercel free subdomain

1. Push this repo to GitHub
2. Import the repo into Vercel
3. In the Vercel project settings, set the Root Directory to `customer-web`
4. Deploy and Vercel will give you a free `*.vercel.app` subdomain
5. If you want a better subdomain, rename the Vercel project and redeploy

This keeps the Flutter app untouched because Vercel only serves the `customer-web` folder.

## Connect live Firebase data

1. Copy values from `firebase-config.example.js` into `firebase-config.js`
2. Replace the phone and WhatsApp numbers in `firebase-config.js`
3. Make sure Firestore rules allow the web app to read `users` and `menuItems`

If Firebase web config is not added, the app uses a built-in sample catalog.
