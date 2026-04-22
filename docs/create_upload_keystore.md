# Create the Zahlivery Upload Keystore

Use this once on your machine to generate the Play Store upload keystore.

## Output file
- `android/upload-keystore.jks`

## Command

```powershell
keytool -genkeypair -v -keystore android\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## What to do during the prompts
- Enter a strong keystore password
- Enter a strong key password
- Use `upload` as the alias
- Fill the owner details

## After the keystore is created

Create:
- `android/key.properties`

Using this content:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

## Important
- Keep `android/upload-keystore.jks` private
- Keep `android/key.properties` private
- Back up the keystore safely
- Do not lose the alias or passwords, because Play Store updates depend on them
