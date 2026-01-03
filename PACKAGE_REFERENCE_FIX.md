# Package Reference Fix - December 16, 2025

## Problem

XcodeGen does not properly link local Swift package dependencies in the generated `project.pbxproj` file. When generating the project, it creates:

```
XCSwiftPackageProductDependency {
    isa = XCSwiftPackageProductDependency;
    productName = AIRoadTripToursApp;
}
```

But it's missing the critical `package` reference:

```
XCSwiftPackageProductDependency {
    isa = XCSwiftPackageProductDependency;
    package = <PACKAGE_ID>;  // ← MISSING!
    productName = AIRoadTripToursApp;
}
```

This causes Xcode to show the error: "Missing package product 'AIRoadTripToursApp'"

## Solution

The `fix_package_reference.sh` script automatically adds the missing `package` reference line after running `xcodegen generate`.

### How It Works

1. Finds the local package reference ID in the project file
2. Locates the `XCSwiftPackageProductDependency` section
3. Adds the missing `package = <ID>` line

### Usage

Always run this script after regenerating the project:

```bash
xcodegen generate
./fix_package_reference.sh
```

Or use the complete regeneration command from IOS_APP_READY.md.

## Technical Details

### XcodeGen Configuration (project.yml)

```yaml
packages:
  AIRoadTripTours:
    path: .
    group: Packages

targets:
  AIRoadTripToursIOSApp:
    dependencies:
      - package: AIRoadTripTours
        product: AIRoadTripToursApp
        link: true
```

Despite `link: true`, XcodeGen still doesn't add the package reference. This appears to be a limitation with local packages at path ".".

### Manual Fix (if script fails)

1. Open `AIRoadTripToursIOSApp.xcodeproj/project.pbxproj` in a text editor
2. Find the package reference ID:
   ```
   A8B526125F1704C4C7B4AB6E /* XCLocalSwiftPackageReference "." */
   ```
3. Find the `XCSwiftPackageProductDependency` section
4. Add the `package` line:
   ```
   75525C2C01EFE368734231FA /* AIRoadTripToursApp */ = {
       isa = XCSwiftPackageProductDependency;
       package = A8B526125F1704C4C7B4AB6E /* XCLocalSwiftPackageReference "." */;
       productName = AIRoadTripToursApp;
   };
   ```

## Verification

Build the project to verify the fix:

```bash
xcodebuild -project AIRoadTripToursIOSApp.xcodeproj \
  -scheme AIRoadTripToursIOSApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

Should see: `** BUILD SUCCEEDED **`

---

**Status**: ✅ Fixed with automated script
**Last Updated**: December 16, 2025
**Related**: IOS_APP_READY.md, DIRECTORY_STRUCTURE_FIX.md
