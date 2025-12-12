# Socrani Tempo - iOS Mobile App

This is the React Native iOS app for Socrani Tempo, built with Expo.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Create a `.env` file in the `mobile` directory with your Supabase credentials:
```
EXPO_PUBLIC_SUPABASE_URL=your_supabase_url
EXPO_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
```

3. Start the development server:
```bash
npm start
```

4. Run on iOS simulator:
```bash
npm run ios
```

## Features

- **Authentication**: Sign up and sign in with email/password using Supabase
- **Email Contacts**: Browse and save email contacts
- **LinkedIn Profiles**: View and save LinkedIn profiles
- **Job Posts**: Search and save job postings
- **Offline Storage**: Saved items persist using AsyncStorage

## Project Structure

```
mobile/
├── app/                    # Expo Router pages
│   ├── (auth)/            # Authentication screens
│   ├── (tabs)/            # Main app tabs (Dashboard, Profile)
│   └── _layout.tsx        # Root layout
├── components/            # Reusable components
├── lib/                   # Utilities and services
│   ├── supabase.ts       # Supabase client
│   └── auth.ts           # Auth functions
└── package.json
```

## Building for Production

To build for iOS:

```bash
eas build --platform ios
```

Make sure you have an Expo account and EAS CLI installed:
```bash
npm install -g eas-cli
eas login
```

## Notes

- The app uses Expo Router for file-based routing
- Supabase authentication is handled with secure storage
- AsyncStorage is used for local data persistence
- The app follows the same data structure as the web app

