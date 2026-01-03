#\!/bin/bash
# Create iOS app Xcode project

PROJECT_NAME="AIRoadTripToursIOSApp"
BUNDLE_ID="com.airoadtriptours.AIRoadTripToursIOSApp"
ORG_NAME="AI Road Trip Tours"

# Create project directory structure if needed
mkdir -p "${PROJECT_NAME}"

# Use xcrun to create a basic iOS app project
# This requires using Xcode's project template
echo "Creating Xcode project..."
echo "Run this command:"
echo ""
echo "xcodegen generate"
echo ""
echo "Or manually in Xcode:"
echo "1. File > New > Project"
echo "2. Choose iOS > App"  
echo "3. Name: ${PROJECT_NAME}"
echo "4. IMPORTANT: When asked where to save, choose 'AIRoadTripTours' folder"
echo "5. UNCHECK 'Create Git repository'"
echo "6. This will create the project NEXT TO existing files, not inside a subfolder"
