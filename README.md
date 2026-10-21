# Xeta UPI Circle App

Xeta UPI Circle helps trusted family and friends coordinate UPI payment requests. Scan or share a request, let a trusted person complete payment in their existing UPI app, and keep transaction notes and proof locally on the device.

## Features

- Scan or share UPI payment requests
- Manage trusted contacts and transaction history
- Save payment proof and cashback notes on the device
- Light and dark themes
- Optional cryptocurrency donations
- No app account or backend

The app does not process payments or verify that a payment was completed. When you share a request, its details are sent to the app you choose, such as WhatsApp.

## Privacy

Read the [privacy policy](assets/privacy_policy.md) or the [website privacy page](assets/Website/build/privacy.html).

## Android build

The Android application ID is `com.xetawallet.xetaupicircleapp`. The first Play release is version `1.0.0` (version code `1000000`).

```sh
flutter pub get
flutter build appbundle --release --build-name 1.0.0 --build-number 1000000
```

Release signing uses `android/key.properties` and `android/upload-keystore.jks`. Keep these local signing files private and backed up; they are excluded from Git.

## Google Play and website assets

Phone screenshots are under `assets/Play Store Assets-Master/Screenshots Taken from Phone/Google Play Screenshots/`. Feature graphics, tablet screenshots, and the static website are generated with the reusable `tool/generate_playstore_package.py` from the [Xeta App Boilerplate](https://github.com/xetawallet/Xeta-App-Boilerplate):

```sh
python3 /path/to/Xeta-App-Boilerplate/Uploaded\ to\ Github/tool/generate_playstore_package.py \
  --app-name "Xeta UPI Circle App" \
  --tagline "Coordinate UPI payments with people you trust." \
  --source-code-url "https://github.com/xetawallet/Xeta-Upi-Circle-App" \
  --assets-root "$PWD/assets" \
  --source-dir "$PWD/assets/Play Store Assets-Master/Screenshots Taken from Phone/Google Play Screenshots" \
  --output-root "$PWD/assets/Play Store Assets-Master" \
  --website-build "$PWD/assets/Website/build" \
  --privacy-file "$PWD/assets/privacy_policy.md" \
  --app-icon "$PWD/assets/app_icon.png" \
  --features-file "$PWD/assets/website_features.json"
```

The public source repository is https://github.com/xetawallet/Xeta-Upi-Circle-App.
