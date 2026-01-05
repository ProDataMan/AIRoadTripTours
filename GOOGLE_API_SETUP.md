# Google Places API Configuration

This document explains how to configure the Google Places API for enriching POI data with descriptions and images.

## Why Google Places API?

The app uses a two-tier approach for fetching POI data:

### Images
1. **First**: Wikipedia Commons (free, no API key required)
2. **Fallback**: Google Places API (requires API key, provides high-quality images)

If Wikipedia Commons has no images for a POI, the app automatically falls back to Google Places API to fetch photos.

### Descriptions
**Google Places API** (requires API key, provides editorial summaries)

When you search for POIs, the app automatically enriches them with descriptions from Google Places API's editorial summaries. This provides context like "A stunning waterfall known for its multiple tiers and scenic hiking trails."

## Setting Up Google Places API

### Step 1: Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Note your project ID

### Step 2: Enable Required APIs

1. In the Google Cloud Console, navigate to "APIs & Services" > "Library"
2. Search for and enable the following APIs:
   - **Places API**
   - **Places API (New)**

### Step 3: Create API Credentials

1. Navigate to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "API Key"
3. Copy the generated API key

### Step 4: Restrict the API Key (Recommended)

For security, restrict your API key:

1. Click on the API key you just created
2. Under "API restrictions":
   - Select "Restrict key"
   - Check "Places API"
3. Under "Application restrictions" (optional):
   - Select "iOS apps"
   - Add your app's bundle identifier
4. Click "Save"

### Step 5: Configure the App

The recommended way to provide API keys is using a `.env` file in the project root.

#### Using .env File (Recommended)

1. Copy the example file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and add your API key:
   ```bash
   GOOGLE_PLACES_API_KEY=your-actual-api-key-here
   ```

3. The `.env` file is automatically gitignored and won't be committed to version control

4. The app will automatically load the `.env` file at startup

#### Alternative: Xcode Environment Variable

You can also add it to your Xcode scheme:
1. Product > Scheme > Edit Scheme
2. Run > Arguments > Environment Variables
3. Add `GOOGLE_PLACES_API_KEY` with your API key value

**Note**: The `.env` file approach is preferred as it persists across launches and is automatically loaded.

## Testing the Configuration

The app will log messages when fetching images and descriptions:

- `📷 No Wikipedia images found for [POI], trying Google Places...` - Image fallback triggered
- `📷 Found X Google Places images for place ID: [ID]` - Google Places images succeeded
- `📝 Enriching X POIs with Google Places data...` - Description enrichment started
- `✅ Enriched X of Y POIs with descriptions` - Description enrichment completed
- `⚠️ Google Places API key not configured, skipping Google image search` - API key missing

## API Costs

Google Places API has usage limits and costs:
- Free tier: $200 monthly credit
- Text Search: $17 per 1000 requests (used for finding places)
- Place Details: $17 per 1000 requests (used for descriptions, ratings, etc.)
- Place Photos: No separate charge (included in Details)

**Current Usage**:
- 1 Text Search request per POI (for images and description)
- 1 Place Details request per POI (for description and metadata)
- Total: ~$0.034 per POI enriched

Monitor usage at: [Google Cloud Console Billing](https://console.cloud.google.com/billing)

## Troubleshooting

### Images Still Not Loading

1. Check that the API key is correctly configured
2. Verify the Places API is enabled in Google Cloud Console
3. Check Xcode console for error messages
4. Ensure network restrictions allow `maps.googleapis.com`

### POI Descriptions Not Appearing

1. Verify the Google Places API key is configured (same key as images)
2. Check console logs for enrichment messages (`📝 Enriching...`)
3. Ensure Places API is enabled with "Place Details" permission
4. Check that POIs are being found (not all places have editorial summaries)

### API Key Errors

- **403 Forbidden**: API not enabled or key restrictions too strict
- **400 Bad Request**: Invalid API key format
- **429 Too Many Requests**: Rate limit exceeded

## Without Google API Key

The app works without a Google API key - it simply won't fetch fallback images or descriptions:
- Wikipedia Commons images still work
- POIs without Wikipedia images show a placeholder icon
- POIs without descriptions show only name, category, distance, and rating
- No errors or crashes occur

## Security Best Practices

1. ✅ Use environment variables instead of hardcoding keys
2. ✅ Restrict API key to specific APIs
3. ✅ Restrict API key to your app's bundle ID
4. ✅ Monitor API usage regularly
5. ✅ Never commit API keys to version control
6. ✅ Rotate keys periodically
