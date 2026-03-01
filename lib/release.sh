#!/bin/bash
cd android

# Optional: altes Build bereinigen
#./gradlew clean

# Release-Bundle bauen
./gradlew bundleRelease

# Erfolgsmeldung
echo "✅ Release-Build erfolgreich erstellt!"
echo "📦 Datei befindet sich unter:"
echo "   android/app/build/outputs/bundle/release/app-release.aab"