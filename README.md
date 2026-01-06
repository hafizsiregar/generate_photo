# AI Travel / Lifestyle Photo Remix App

A Flutter application that transforms portrait photos into AI-generated travel and lifestyle scenes using Google's Gemini image generation API (NanoBanana). Upload a single portrait photo and receive multiple professionally styled scenes perfect for social media.

## Features

- **Single-Screen Interface**: Clean, modern UI following Apple Design Award principles
- **Photo Upload**: Choose from camera or gallery with intuitive selection
- **AI Image Generation**: Transform portraits into 3 different lifestyle scenes:
  - Sunny beach travel scene
  - Futuristic city rooftop at night  
  - Cozy cafe lifestyle photo
- **Real-time Status**: Live updates during generation process
- **Secure Storage**: All images stored securely in Firebase with user isolation
- **Responsive Design**: Works across different phone sizes

## Tech Stack

- **Frontend**: Flutter with Material 3 design
- **Backend**: Firebase Cloud Functions (Node.js 20)
- **Database**: Firebase Firestore
- **Storage**: Firebase Storage
- **Authentication**: Firebase Anonymous Authentication
- **AI Generation**: Google Gemini 2.5 Flash Image API (NanoBanana)
- **Security**: Firebase Security Rules

## Architecture

```
User Upload → Firebase Storage → Cloud Function → Gemini API → Generated Images → Firebase Storage → Display
```

### Flow Explanation:
1. User uploads portrait photo via Flutter app
2. Image stored in Firebase Storage with user-specific path
3. Metadata saved to Firestore with generation status
4. Cloud Function triggered with remix ID
5. Function downloads original image and calls Gemini API
6. AI generates 3 scene variations with different prompts
7. Generated images saved back to Firebase Storage
8. App displays original + generated images in grid layout

## Security Approach

### API Key Protection
- Gemini API key stored as Firebase secret (not exposed in client)
- All AI calls routed through secure Cloud Functions
- No sensitive credentials in Flutter app

### Authentication & Authorization
- Firebase Anonymous Authentication for user sessions
- Cloud Functions set to "private" invoker (not public access)
- User authentication required for all operations
- User-specific data isolation with Firebase Security Rules

### Rate Limiting & Abuse Prevention
- Maximum 15 generations per user per hour (increased from 10)
- Minimum 10 seconds between successful requests (reduced from 30)
- Failed requests don't count toward time limit (immediate retry allowed)
- Request tracking in Firestore to prevent abuse
- Concurrent instance limits (max 10) to control costs

### User Data Isolation
- Firebase Security Rules ensure users only access their own data
- Storage paths include user ID: `/images/{userId}/{remixId}/`
- Firestore documents filtered by `userId` field
- Cross-user access attempts are logged and blocked

### Input Validation & Security Checks
- Image size limits (20MB max)
- Content type validation (images only)
- File existence validation before processing
- Duplicate generation prevention
- Comprehensive error logging for security monitoring

### Infrastructure Security
- Cloud Functions with private invoker settings
- Firebase Security Rules for database and storage
- Automatic scaling with resource limits
- Memory and timeout constraints to prevent resource abuse

## Setup Instructions

### Prerequisites
- Flutter SDK (latest stable)
- Firebase CLI
- Google Cloud account with Gemini API access
- Node.js 20+ for Cloud Functions

### 1. Clone Repository
```bash
git clone <repository-url>
cd generate_photo
```

### 2. Install Dependencies
```bash
# Flutter dependencies
flutter pub get

# Cloud Functions dependencies
cd functions
npm install
cd ..
```

### 3. Firebase Configuration
```bash
# Login to Firebase
firebase login

# Initialize project (if not already done)
firebase init

# Set your Firebase project
firebase use <your-project-id>
```

### 4. Configure Firebase Options
```bash
# Generate Firebase configuration
flutter packages pub run build_runner build

# OR manually copy from template
cp lib/firebase_options.dart.template lib/firebase_options.dart
# Then edit lib/firebase_options.dart with your actual Firebase config values
```

### 5. Configure Gemini API Key
```bash
# Set the API key as Firebase secret
firebase functions:secrets:set GEMINI_API_KEY
# Enter your Gemini API key when prompted
```

### 6. Deploy Cloud Functions
```bash
firebase deploy --only functions
```

### 7. Run the App
```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart              # Main app with UI and Firebase integration
├── firebase_options.dart  # Firebase configuration

functions/
├── src/
│   └── index.ts          # Cloud Function for AI generation
├── package.json          # Node.js dependencies
└── tsconfig.json         # TypeScript configuration

firebase.json              # Firebase project configuration
firestore.rules           # Database security rules
storage.rules             # Storage security rules
```

## Usage

1. **Upload Photo**: Tap "Upload photo" and select a portrait image
2. **Generate Scenes**: Tap "Generate scenes" to start AI processing
3. **View Results**: Generated images appear in grid below original
4. **Status Updates**: Monitor progress via status indicator

## Development Notes

- Uses Firebase Anonymous Authentication for user sessions
- Images include SynthID watermark (Gemini requirement)
- Generation typically takes 30-60 seconds for 3 images
- Error handling includes retry logic and user feedback
- Responsive design adapts to different screen sizes

## Troubleshooting

### Common Issues

**"API key missing or invalid"**
- Ensure Gemini API key is set: `firebase functions:secrets:access GEMINI_API_KEY`
- Verify API key has image generation permissions

**"Generation failed"**
- Check Firebase Functions logs: `firebase functions:log --only generateImages`
- Verify Gemini API quota and billing status

**"Upload failed"**
- Check image size (must be < 20MB)
- Verify image format (JPEG/PNG supported)
- Ensure stable internet connection

### Logs and Debugging
```bash
# View function logs
firebase functions:log --only generateImages

# Deploy with debug
firebase deploy --only functions --debug
```

## License

This project is a technical demonstration built for evaluation purposes.
