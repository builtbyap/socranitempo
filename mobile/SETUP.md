# iOS App Setup Guide

## Prerequisites

1. **Node.js** (v18 or higher)
2. **npm** or **yarn**
3. **Xcode** (for iOS development)
4. **Expo CLI** (optional, but recommended)
5. **Supabase account** with your project credentials

## Installation Steps

### 1. Install Dependencies

Navigate to the `mobile` directory and install dependencies:

```bash
cd mobile
npm install
```

### 2. Configure Environment Variables

Create a `.env` file in the `mobile` directory:

```bash
EXPO_PUBLIC_SUPABASE_URL=your_supabase_url_here
EXPO_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key_here
```

Replace the placeholders with your actual Supabase credentials from your Supabase project dashboard.

### 3. Start the Development Server

```bash
npm start
```

This will start the Expo development server. You'll see a QR code in your terminal.

### 4. Run on iOS Simulator

**Option A: Using Expo Go (Easiest)**
1. Install Expo Go from the App Store on your iPhone
2. Scan the QR code with your camera app
3. The app will open in Expo Go

**Option B: Using iOS Simulator (Development)**
```bash
npm run ios
```

This requires Xcode to be installed and will open the iOS Simulator.

## Project Structure

```
mobile/
├── app/                      # Expo Router pages (file-based routing)
│   ├── (auth)/              # Authentication screens
│   │   ├── sign-in.tsx     # Sign in screen
│   │   └── sign-up.tsx     # Sign up screen
│   ├── (tabs)/              # Main app tabs
│   │   ├── dashboard.tsx   # Dashboard with tabs
│   │   └── profile.tsx     # User profile
│   ├── _layout.tsx          # Root layout
│   └── index.tsx            # Entry point (redirects based on auth)
├── components/              # React Native components
│   ├── EmailListTab.tsx    # Email contacts tab
│   ├── LinkedInProfilesTab.tsx  # LinkedIn profiles tab
│   └── JobsPostsTab.tsx    # Job posts tab
├── lib/                     # Utilities
│   ├── supabase.ts         # Supabase client configuration
│   └── auth.ts             # Authentication functions
├── app.json                 # Expo configuration
├── package.json            # Dependencies
└── tsconfig.json           # TypeScript configuration
```

## Features

✅ **Authentication**
- Email/password sign up and sign in
- Secure session management with Expo SecureStore
- Automatic session refresh

✅ **Email Contacts**
- Browse email contacts from Supabase
- Search functionality
- Save/unsave contacts
- Send emails directly from the app

✅ **LinkedIn Profiles**
- View LinkedIn profiles
- Search by name, title, or company
- Save favorite profiles
- Open LinkedIn profiles in browser

✅ **Job Posts**
- Browse job postings
- Search jobs
- Save job posts
- View job details

✅ **Offline Support**
- Saved items persist using AsyncStorage
- Works offline for saved content

## Building for Production

### Using EAS Build (Recommended)

1. Install EAS CLI:
```bash
npm install -g eas-cli
```

2. Login to Expo:
```bash
eas login
```

3. Configure your project:
```bash
eas build:configure
```

4. Build for iOS:
```bash
eas build --platform ios
```

### Using Expo Build (Legacy)

```bash
expo build:ios
```

## Troubleshooting

### Common Issues

1. **"Module not found" errors**
   - Run `npm install` again
   - Clear cache: `npm start -- --clear`

2. **Supabase connection issues**
   - Verify your `.env` file has correct credentials
   - Check that your Supabase project is active
   - Ensure RLS policies allow access

3. **iOS Simulator not opening**
   - Make sure Xcode is installed
   - Run `xcode-select --install` if needed
   - Check that Xcode Command Line Tools are installed

4. **Expo Go connection issues**
   - Ensure your phone and computer are on the same WiFi network
   - Try using the tunnel option: `npm start -- --tunnel`

## Next Steps

1. **Customize the app icon**: Replace `./assets/icon.png` with your icon
2. **Update app name**: Edit `app.json` to change the display name
3. **Add app icons**: Generate icons using `expo install expo-asset`
4. **Configure deep linking**: Set up URL schemes in `app.json`
5. **Add push notifications**: Configure with `expo-notifications`

## Resources

- [Expo Documentation](https://docs.expo.dev/)
- [React Native Documentation](https://reactnative.dev/)
- [Supabase Mobile Guide](https://supabase.com/docs/guides/getting-started/tutorials/with-expo-react-native)
- [Expo Router Documentation](https://docs.expo.dev/router/introduction/)

