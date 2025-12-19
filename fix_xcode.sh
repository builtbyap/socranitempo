#!/bin/bash

# Script to fix Xcode project opening issues

echo "🔧 Fixing Xcode project opening issues..."

# Navigate to project directory
cd "$(dirname "$0")"

# 1. Clean derived data
echo "📦 Cleaning derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/surgeapp-* 2>/dev/null
rm -rf ~/Library/Developer/Xcode/DerivedData/*/Build/Products/*/surgeapp* 2>/dev/null

# 2. Clean user data
echo "🧹 Cleaning user data..."
rm -rf surgeapp.xcodeproj/project.xcworkspace/xcuserdata 2>/dev/null
rm -rf surgeapp.xcodeproj/xcuserdata 2>/dev/null

# 3. Clean module cache
echo "🗑️  Cleaning module cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex 2>/dev/null

# 4. Clean SwiftPM cache
echo "📚 Cleaning SwiftPM cache..."
rm -rf .swiftpm 2>/dev/null
rm -rf surgeapp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm 2>/dev/null

# 5. Verify project file integrity
echo "✅ Verifying project file..."
if plutil -lint surgeapp.xcodeproj/project.pbxproj > /dev/null 2>&1; then
    echo "   ✓ Project file is valid"
else
    echo "   ✗ Project file may be corrupted!"
    exit 1
fi

# 6. Kill any hanging Xcode processes
echo "🔄 Killing hanging Xcode processes..."
killall Xcode 2>/dev/null
sleep 2

# 7. Try to open the project
echo "🚀 Opening project in Xcode..."
open surgeapp.xcodeproj

echo ""
echo "✨ Done! Xcode should open now."
echo ""
echo "If Xcode still doesn't open, try:"
echo "  1. Restart your Mac"
echo "  2. Update Xcode: xcode-select --install"
echo "  3. Open Xcode manually, then File > Open > surgeapp.xcodeproj"

