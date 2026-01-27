#!/bin/bash

# Script to create a GitHub Release with opus files (or mp3 files)
# This script requires the GitHub CLI (gh) to be installed and authenticated

# Get repository name from git remote
REPO_NAME=$(git remote get-url origin | sed -E 's/.*[:/]([^/]+\/[^/]+)(\.git)?$/\1/')
if [ -z "$REPO_NAME" ]; then
    echo "Error: Could not determine repository name from git remote."
    echo "Please ensure this directory is a git repository with a valid remote."
    exit 1
fi

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Warning: GitHub CLI (gh) is not installed."
    echo "The script will attempt to continue without it, but some features may not work."
    echo "For full functionality, please install GitHub CLI:"
    echo "Visit: https://cli.github.com/ for installation instructions"
    GH_INSTALLED=false
else
    GH_INSTALLED=true
fi

# Check if user is authenticated with GitHub CLI (only if installed)
if [ "$GH_INSTALLED" = true ] && ! gh auth status &> /dev/null; then
    echo "Warning: You are not authenticated with GitHub CLI."
    echo "The script will attempt to continue, but you may encounter permission issues."
    echo "For full functionality, please run 'gh auth login' to authenticate."
fi

# Check if we can access the repository via GitHub API
if ! curl -s "https://api.github.com/repos/$REPO_NAME" > /dev/null; then
    echo "Warning: Cannot access repository via GitHub API."
    echo "This may cause issues when creating the release."
    echo "Please check that:"
    echo "1. The repository exists on GitHub"
    echo "2. You have the correct permissions"
    echo "3. Your git remote is correctly configured"
    echo "Current repository from git remote: $REPO_NAME"
fi

# Check if opus directory exists (preferred) or mp3 directory as fallback
if [ -d "opus" ]; then
    AUDIO_FORMAT="opus"
    AUDIO_DIR="opus"
elif [ -d "mp3" ]; then
    AUDIO_FORMAT="mp3"
    AUDIO_DIR="mp3"
else
    echo "Error: Neither opus nor mp3 directory found."
    echo "Please run convert_flac_to_opus.sh (recommended) or convert_flac_to_mp3.sh first."
    exit 1
fi

echo "Using $AUDIO_FORMAT format for release."

# Ask for release tag
read -p "Enter release tag (e.g., v1.0.0): " RELEASE_TAG

# Ask for release title
read -p "Enter release title: " RELEASE_TITLE

# Ask for release notes
echo "Enter release notes (press Ctrl+D when done):"
RELEASE_NOTES=$(cat)

# Create a temporary zip file of the audio directory
echo "Creating zip file of $AUDIO_DIR directory..."
zip -r ${AUDIO_FORMAT}_files.zip $AUDIO_DIR/

# Create the release
echo "Creating GitHub Release..."
# Check if we can access the repository via GitHub API
if ! curl -s "https://api.github.com/repos/$REPO_NAME" > /dev/null; then
    echo "Error: Cannot access repository via GitHub API."
    echo "Please check that:"
    echo "1. The repository exists on GitHub"
    echo "2. You have the correct permissions"
    echo "3. Your git remote is correctly configured"
    echo "Current repository from git remote: $REPO_NAME"
    echo ""
    echo "If you're sure the repository exists, please install and authenticate GitHub CLI:"
    echo "1. Install GitHub CLI: https://cli.github.com/"
    echo "2. Authenticate: gh auth login"
    exit 1
fi

if [ "$GH_INSTALLED" = true ]; then
    # Use GitHub CLI to create the release
    gh release create "$RELEASE_TAG" ${AUDIO_FORMAT}_files.zip --title "$RELEASE_TITLE" --notes "$RELEASE_NOTES"
else
    echo "Error: GitHub CLI (gh) is required to create releases."
    echo "Please install GitHub CLI and try again:"
    echo "1. Install GitHub CLI: https://cli.github.com/"
    echo "2. Authenticate: gh auth login"
    echo ""
    echo "Alternatively, you can manually create a release on GitHub:"
    echo "1. Go to https://github.com/$REPO_NAME/releases/new"
    echo "2. Enter '$RELEASE_TAG' as the tag"
    echo "3. Enter '$RELEASE_TITLE' as the title"
    echo "4. Paste your release notes"
    echo "5. Upload the ${AUDIO_FORMAT}_files.zip file"
    echo ""
    echo "The zip file has been created at: $(pwd)/${AUDIO_FORMAT}_files.zip"
    echo "Would you like to continue updating the index.html file? (y/n)"
    read -r CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled. Please delete the zip file manually."
        exit 1
    fi
fi

# Clean up
rm ${AUDIO_FORMAT}_files.zip

# Update the AudioLoader configuration in index.html
echo "Updating AudioLoader configuration in index.html..."
sed -i "s/releaseTag: '[^']*'/releaseTag: '$RELEASE_TAG'/g" index.html

echo "Done! GitHub Release created with tag: $RELEASE_TAG"
echo "The AudioLoader configuration in index.html has been updated."
echo ""
echo "To use jsDelivr CDN, your audio files can now be accessed at:"
# Use git remote to get the repository name if gh is not available
REPO_NAME=$(git remote get-url origin | sed -E 's/.*[:/]([^/]+\/[^/]+)(\.git)?$/\1/')
echo "https://cdn.jsdelivr.net/gh/$REPO_NAME@$RELEASE_TAG/$AUDIO_DIR/samples/[directory]/[filename].$AUDIO_FORMAT"