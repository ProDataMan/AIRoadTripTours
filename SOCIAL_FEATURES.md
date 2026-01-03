# Social Features and Community Sharing

This guide explains the social features and community sharing capabilities in AI Road Trip Tours.

## Overview

The social features enable users to share their best tours with the community, discover popular routes created by others, and
provide feedback to improve the touring experience. The system includes automatic promotion of highly-rated tours and lays
the foundation for AI-driven curation.

## Features

### Tour Sharing

Users can share completed tours with the community:

- Manual sharing from tour history.
- Automatic sharing of highly-rated tours (5-star ratings).
- Customizable tour metadata (title, description, tags, difficulty, season).
- Pre-generated suggestions based on tour content.

### Community Discovery

Browse and discover tours shared by others:

- Sort by popularity, rating, recent, or trending.
- Search by text, categories, or location.
- View detailed tour information and statistics.
- See community ratings and feedback.
- Filter by difficulty level and season.

### Rating System

Multi-dimensional rating system:

- Overall rating (1-5 stars).
- Route quality rating.
- POI selection rating.
- Narration quality rating.
- Experience rating.
- Average component ratings calculated automatically.

### Feedback System

Detailed feedback mechanism:

- Feedback types: Positive, Constructive, Issue, Suggestion.
- Aspect tagging: Route, POIs, Narration, Timing, Safety, etc.
- Helpful voting on feedback.
- Moderation support.

### Engagement Metrics

Track tour popularity and engagement:

- View count.
- Completion count.
- Save/favorite count.
- Share count.
- Popularity score calculation.
- Trending score tracking.

## Architecture

### Data Models

#### SharedTour

Represents a tour shared with the community:

```swift
struct SharedTour {
    let id: UUID
    let creatorId: String
    let creatorName: String
    let title: String
    let description: String
    let pois: [POI]
    let startLocation: GeoLocation
    let totalDistance: Double
    let estimatedDuration: Double
    let categories: Set<POICategory>
    let sharedAt: Date
    let isAutoShared: Bool
    let isCurated: Bool
    var metrics: CommunityMetrics
    let tags: Set<String>
    let difficulty: TourDifficulty
    let bestSeason: Season?
    var isFeatured: Bool
    let version: Int
    let lastUpdated: Date
}
```

#### TourRating

User rating for a shared tour:

```swift
struct TourRating {
    let id: UUID
    let tourId: UUID
    let userId: String
    let overallRating: Int
    let routeQuality: Int
    let poiQuality: Int
    let narrationQuality: Int
    let experienceRating: Int
    let createdAt: Date
    let completedTour: Bool
    let tourDate: Date?
}
```

#### TourFeedback

Detailed feedback and comments:

```swift
struct TourFeedback {
    let id: UUID
    let tourId: UUID
    let userId: String
    let userName: String
    let comment: String
    let type: FeedbackType
    let aspects: Set<FeedbackAspect>
    let createdAt: Date
    var helpfulCount: Int
    var isReviewed: Bool
    var usedInAIUpdate: Bool
    let ratingId: UUID?
}
```

#### CommunityMetrics

Engagement and popularity metrics:

```swift
struct CommunityMetrics {
    var viewCount: Int
    var completionCount: Int
    var saveCount: Int
    var shareCount: Int
    var averageRating: Double
    var ratingCount: Int
    var feedbackCount: Int
    var popularityScore: Double
    var trendingScore: Double
}
```

### Services

#### CommunityTourRepository

Actor-based repository for managing community tours:

```swift
actor CommunityTourRepository {
    // Sharing
    func shareTour(...) async throws -> SharedTour
    func autoShareIfQualified(...) async throws -> SharedTour?

    // Discovery
    func getAllTours(limit: Int, sortBy: TourSortOption) async -> [SharedTour]
    func getFeaturedTours(limit: Int) async -> [SharedTour]
    func getToursNear(location: GeoLocation, radiusMiles: Double) async -> [SharedTour]
    func getToursByCategories(_ categories: Set<POICategory>) async -> [SharedTour]
    func searchTours(query: String) async -> [SharedTour]

    // Ratings
    func submitRating(tourId: UUID, userId: String, rating: TourRating) async throws -> SharedTour
    func getRatings(for tourId: UUID) async -> [TourRating]
    func getUserRating(userId: String, tourId: UUID) async -> TourRating?

    // Feedback
    func submitFeedback(tourId: UUID, feedback: TourFeedback) async throws -> SharedTour
    func getFeedback(for tourId: UUID) async -> [TourFeedback]
    func markFeedbackHelpful(feedbackId: UUID, tourId: UUID) async

    // Metrics
    func recordView(tourId: UUID) async
    func recordCompletion(tourId: UUID) async
    func recordSave(tourId: UUID) async
    func recordShare(tourId: UUID) async
}
```

### User Interface

#### CommunityToursView

Main browsing interface:

- Tab-based sorting (Popularity, Rating, Recent, Trending).
- Search functionality.
- Tour cards with ratings and stats.
- Tap to view detailed tour information.

#### CommunityTourDetailView

Detailed tour information:

- Tour header with metadata.
- Statistics and metrics.
- Rating summary.
- POI list with descriptions.
- Community feedback display.
- Actions: Save, Share, Rate, Provide Feedback.
- Start tour button.

#### ShareTourView

Share a completed tour:

- Auto-generated title and description.
- Difficulty and season selection.
- Tag suggestions based on tour content.
- Preview before sharing.

#### RateTourView

Rate a completed tour:

- Overall and component ratings (1-5 stars).
- Optional feedback text.
- Feedback type and aspect selection.
- Tour summary display.

## Automatic Tour Sharing

Tours are automatically shared when they meet quality thresholds:

### Criteria

- User must rate the tour 5 stars overall.
- User must have completed the tour.
- Tour receives high ratings across components.

### Process

1. User completes tour.
2. User rates tour with 5 stars.
3. System generates title, description, and tags.
4. Tour automatically shared with `isAutoShared: true` flag.
5. Tour appears in community feed.

### Auto-Generated Content

Title generation:

- Single POI: POI name.
- Two POIs: "POI1 and POI2".
- Multiple: "POI1, POI2, and N more".

Description generation:

- Distance and duration.
- POI count.
- Category highlight.
- "Highly rated experience" notation.

Tag generation:

- Category-based (from POI categories).
- Distance-based (Short Trip, Day Trip, Road Trip).
- Duration-based (Quick Tour, Half Day, Full Day).
- POI count-based (Few Stops, Several Stops, Many Stops).

Difficulty estimation:

- Easy: < 100 miles, ≤ 5 POIs.
- Moderate: 100-300 miles, 5-10 POIs.
- Challenging: > 300 miles or > 10 POIs.

## Future: AI-Driven Curation

The system is designed to support AI-driven curation and updates:

### Planned Features

#### Permanent Tour Storage

- Best tours saved permanently to dedicated repository.
- Version tracking for tour updates.
- Historical version access.

#### AI-Based Updates

- Analyze community feedback for improvement suggestions.
- Identify route optimizations.
- Suggest better POI selections.
- Update narration based on user comments.
- Adapt to seasonal changes.

#### Curation Process

1. Collect community feedback and ratings.
2. Analyze feedback using AI (sentiment, themes, suggestions).
3. Generate improvement recommendations.
4. Apply updates to tour routes and content.
5. Increment version number.
6. Track which feedback was incorporated.

#### Quality Indicators

- `isCurated: Bool` - Tour reviewed and approved.
- `isFeatured: Bool` - Promoted tour with high engagement.
- `version: Int` - Track tour iterations.
- `usedInAIUpdate: Bool` - Feedback incorporated in updates.

### Data Collection for AI

Feedback structure supports AI analysis:

- Type classification (Positive, Constructive, Issue, Suggestion).
- Aspect tagging (Route, POIs, Narration, etc.).
- Free-form text comments.
- Helpful voting for quality signal.
- Reviewer status for trust scoring.

### Metrics for Curation

Popularity score calculation:

```swift
popularityScore =
    (viewCount × 1.0) +
    (completionCount × 5.0) +
    (saveCount × 3.0) +
    (shareCount × 4.0) +
    (averageRating × ratingCount × 2.0)
```

Trending score:

- Weight recent activity more heavily.
- Time-decay function for older tours.
- Spike detection for viral tours.

## Integration Points

### Tour History

- Share button in tour detail view.
- Rate button in tour detail view.
- Automatic share suggestion after 5-star rating.

### Audio Tour Manager

- Track completion for rating prompts.
- Collect playback metrics.
- Support automatic sharing workflow.

### Main Navigation

- Community tab in main tab bar.
- Browse and discover community tours.
- Start tours directly from community feed.

## Best Practices

### Sharing Tours

- Provide descriptive titles that highlight unique aspects.
- Write clear descriptions explaining what makes the tour special.
- Add relevant tags for discoverability.
- Set appropriate difficulty and season.
- Share tours that offer unique value.

### Rating Tours

- Complete the tour before rating.
- Rate honestly across all dimensions.
- Provide constructive feedback.
- Highlight specific aspects (good or bad).

### Providing Feedback

- Be specific and actionable.
- Focus on the experience, not the person.
- Use aspect tags to categorize comments.
- Vote helpful on useful feedback from others.

## Privacy and Safety

### User Data

- Creator name displayed with shared tours.
- No personal location data exposed.
- User IDs anonymized in backend.

### Content Moderation

- Feedback review system.
- Report inappropriate content.
- Moderation flags on feedback.
- Community guidelines enforcement.

### Tour Quality

- Rating validation (1-5 range).
- Spam detection on feedback.
- Quality thresholds for featuring.

## Testing

### Manual Testing

1. Complete a tour.
2. Rate it with 5 stars.
3. Verify automatic sharing.
4. Browse community tours.
5. View tour details.
6. Submit feedback.
7. Rate a community tour.
8. Share a tour manually.

### Metrics Verification

1. Record views.
2. Track completions.
3. Monitor saves.
4. Count shares.
5. Calculate popularity scores.
6. Verify trending calculations.

## Future Enhancements

- Social profiles for prolific tour creators.
- Follow favorite creators.
- Tour collections and playlists.
- Regional tour highlights.
- Seasonal tour recommendations.
- AI-powered tour personalization.
- Machine learning for route optimization.
- Natural language processing for feedback analysis.
- Automated tour quality scoring.
- Dynamic tour updates based on real-time conditions.
