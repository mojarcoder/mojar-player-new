#!/bin/bash

# Build and run Mojar Player Pro for Linux
echo "Building and running Mojar Player Pro..."

# Make sure we have the latest dependencies
flutter pub get

# Build the Linux release
flutter build linux --release

# Make the run script executable
chmod +x run.sh

# Copy the run script to the build directory
cp run.sh build/linux/x64/release/bundle/

# Navigate to the build directory
cd build/linux/x64/release/bundle/

# Make the application executable
chmod +x mojar-player-pro

# Run the application with the environment setup script
./run.sh