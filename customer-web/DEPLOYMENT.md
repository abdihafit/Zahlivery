# Zahlivery Web Deployment

This web app is ready for a free Vercel subdomain and can behave like an app on iPhone Safari and Chrome.

## 1. What Vercel does automatically

When you create a Vercel project and deploy it, Vercel automatically gives you a free subdomain like:

- `zahlivery-web.vercel.app`
- `your-project-name.vercel.app`

You do not manually create the DNS for that free Vercel subdomain. Vercel creates it for you after the project is imported or deployed.

The only thing you control is the project name, because that affects the subdomain name.

## 2. How to get the free Vercel subdomain

1. Push this repo to GitHub.
2. Open `https://vercel.com/new`.
3. Import the GitHub repository.
4. In Vercel project setup, set:
   - `Root Directory` = `customer-web`
   - Framework Preset = `Other`
5. Click `Deploy`.
6. After deployment, Vercel will generate a free `*.vercel.app` URL.

If you want a different subdomain name, rename the Vercel project and redeploy.

## 3. Firebase web config you need

Open [firebase-config.js](C:/Users/AHMED/Pictures/HECO/zahlivery/customer-web/firebase-config.js:1) and replace the placeholder values using your Firebase project's web app config.

You need these values:

- `apiKey`
- `authDomain`
- `projectId`
- `storageBucket`
- `messagingSenderId`
- `appId`

Use this structure:

```js
window.ZAHLIVERY_FIREBASE_CONFIG = {
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_PROJECT.firebaseapp.com",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_PROJECT.firebasestorage.app",
  messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
  appId: "YOUR_APP_ID",
};

window.ZAHLIVERY_WEB_SETTINGS = {
  businessPhone: "+254700000000",
  businessWhatsApp: "254700000000",
  customerPrompt:
    "Hello Zahlivery, I would like to place this order from the web app:",
};
```

## 4. Where to find Firebase web config

1. Open Firebase Console.
2. Open your project.
3. Go to `Project settings`.
4. Scroll to `Your apps`.
5. If you do not already have a Web App, click `</>` to add one.
6. Copy the Firebase config object values into `firebase-config.js`.

## 5. Firestore access reminder

For the live catalog to work, the web app needs read access to:

- `users`
- `users/{shopId}/menuItems`

If Firestore rules block public or customer reads, the web app will fall back to sample catalog data.

## 6. Install as an app

### iPhone Safari

1. Open the Vercel URL in Safari.
2. Tap `Share`.
3. Tap `Add to Home Screen`.
4. Launch it from the home screen like an app.

### Chrome or Edge

1. Open the Vercel URL.
2. Tap the install icon or browser menu.
3. Choose `Install app` or `Add to Home screen`.

## 7. If you want me to deploy it

I can help with the repo-side setup, but the actual Vercel project creation usually needs your Vercel account login or GitHub import permission.

Once your Vercel account is connected in this environment, I can handle the rest of the deployment steps for you.
