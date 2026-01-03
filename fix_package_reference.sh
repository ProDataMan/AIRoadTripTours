#!/bin/bash
# Fix XcodeGen missing package reference in project.pbxproj
# This script adds the package reference to the XCSwiftPackageProductDependency

PROJECT_FILE="AIRoadTripToursIOSApp.xcodeproj/project.pbxproj"

echo "Fixing package reference in $PROJECT_FILE..."

# Find the package reference ID
PACKAGE_ID=$(grep "XCLocalSwiftPackageReference" "$PROJECT_FILE" | grep -o '[A-F0-9]\{24\}' | head -1)

if [ -z "$PACKAGE_ID" ]; then
    echo "Error: Could not find package reference ID"
    exit 1
fi

echo "Found package ID: $PACKAGE_ID"

# Add package reference to XCSwiftPackageProductDependency if missing
if grep -q "package = $PACKAGE_ID" "$PROJECT_FILE"; then
    echo "Package reference already exists"
else
    echo "Adding package reference..."
    # Use sed to add the package line after "isa = XCSwiftPackageProductDependency;"
    sed -i '' "/XCSwiftPackageProductDependency section/,/End XCSwiftPackageProductDependency section/ {
        /isa = XCSwiftPackageProductDependency;/a\\
			package = $PACKAGE_ID /* XCLocalSwiftPackageReference \".\" */;
    }" "$PROJECT_FILE"
    echo "✅ Package reference added successfully"
fi

echo "Done!"
