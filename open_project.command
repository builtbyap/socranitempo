#!/bin/bash

# Double-click this file to open the Xcode project

cd "$(dirname "$0")"

echo "Opening surgeapp.xcodeproj in Xcode..."
echo ""

# Try multiple methods to open Xcode
if [ -d "surgeapp.xcodeproj" ]; then
    # Method 1: Direct open
    open surgeapp.xcodeproj
    
    # Wait a moment
    sleep 2
    
    # Check if Xcode opened
    if pgrep -x "Xcode" > /dev/null; then
        echo "✅ Xcode is opening the project!"
    else
        echo "⚠️  Xcode may not have opened. Try:"
        echo "   1. Open Xcode manually from Applications"
        echo "   2. Go to File > Open"
        echo "   3. Select this folder and choose surgeapp.xcodeproj"
    fi
else
    echo "❌ Error: surgeapp.xcodeproj not found!"
    echo "   Make sure you're in the correct directory."
fi

echo ""
read -p "Press Enter to close this window..."

