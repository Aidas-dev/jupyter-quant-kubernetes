#!/bin/bash
# Pre-flight check for Docker builds
# Run this BEFORE pushing a tag

set -e

echo "🔍 Running pre-flight Docker build checks..."

# Test CPU Dockerfile
echo "📦 Testing CPU Dockerfile..."
docker build -t test-cpu -f Dockerfile --no-push .

# Test NVIDIA Dockerfile
echo "🟢 Testing NVIDIA Dockerfile..."
docker build -t test-nvidia -f Dockerfile.nvidia --no-push .

# Test AMD Dockerfile  
echo "🔴 Testing AMD Dockerfile..."
docker build -t test-amd -f Dockerfile.amd --no-push .

echo "✅ All Dockerfiles build successfully!"
echo "🚀 Ready to push tag"
