#!/bin/bash

# Sync app code to shopmate-app-code repository
# Usage: ./sync-app-code.sh [commit-message]

COMMIT_MSG=${1:-"Update app code"}
APP_REPO_PATH="../shopmate-app-code"

echo "🔄 Syncing app code to shopmate-app-code repository..."

# Check if app repo exists
if [ ! -d "$APP_REPO_PATH" ]; then
  echo "❌ shopmate-app-code repository not found at $APP_REPO_PATH"
  exit 1
fi

# Copy app files
echo "📁 Copying app files..."
cp app.js "$APP_REPO_PATH/"
cp package.json "$APP_REPO_PATH/"
cp package-lock.json "$APP_REPO_PATH/"
cp Dockerfile "$APP_REPO_PATH/"
cp README.md "$APP_REPO_PATH/"

# Copy directories
cp -r controllers "$APP_REPO_PATH/"
cp -r models "$APP_REPO_PATH/"
cp -r routes "$APP_REPO_PATH/"
cp -r views "$APP_REPO_PATH/"
cp -r public "$APP_REPO_PATH/"
cp -r utils "$APP_REPO_PATH/"

# Navigate to app repo and commit
cd "$APP_REPO_PATH"

echo "📝 Committing changes..."
git add .
git commit -m "$COMMIT_MSG"
git push origin main

echo "✅ App code synced successfully!"
echo "🌐 Repository: shopmate-app-code"