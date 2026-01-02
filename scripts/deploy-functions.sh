#!/bin/bash

# Cloud Functions Deployment Script
# This script builds and deploys Firebase Cloud Functions for budget tracking

set -e  # Exit on error

echo "========================================="
echo "Firebase Cloud Functions Deployment"
echo "========================================="
echo ""

# Check if we're in the correct directory
if [ ! -d "functions" ]; then
    echo "❌ Error: functions/ directory not found"
    echo "Please run this script from the project root directory"
    exit 1
fi

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Error: Firebase CLI not found"
    echo "Please install it with: npm install -g firebase-tools"
    exit 1
fi

# Check if logged in to Firebase
if ! firebase projects:list &> /dev/null; then
    echo "❌ Error: Not logged in to Firebase"
    echo "Please run: firebase login"
    exit 1
fi

# Show current project
echo "📋 Current Firebase project:"
firebase use
echo ""

# Navigate to functions directory
cd functions

# Install dependencies
echo "📦 Installing dependencies..."
npm install
echo ""

# Build TypeScript
echo "🔨 Building TypeScript..."
npm run build
echo ""

# Check if build was successful
if [ ! -f "lib/index.js" ]; then
    echo "❌ Error: Build failed - lib/index.js not found"
    exit 1
fi

echo "✅ Build successful!"
echo ""

# Deploy functions
echo "🚀 Deploying functions to Firebase..."
npm run deploy

echo ""
echo "========================================="
echo "✅ Deployment Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Verify functions in Firebase Console"
echo "2. Create a test transaction in the app"
echo "3. Check budget usage updates automatically"
echo ""
echo "To view logs:"
echo "  firebase functions:log"
echo ""
echo "To view specific function logs:"
echo "  firebase functions:log --only onTransactionCreate"
echo ""
