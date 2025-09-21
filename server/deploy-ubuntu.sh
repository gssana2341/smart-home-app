#!/bin/bash

# Smart Home Server Deployment Script for Ubuntu Instance
# Usage: ./deploy-ubuntu.sh

echo "🚀 Starting deployment to Ubuntu Instance..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo "✅ Docker installed. Please logout and login again, then run this script again."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/bin/docker-compose
    echo "✅ Docker Compose installed."
fi

# Create data directory
mkdir -p ./data

# Stop existing container if running
echo "🛑 Stopping existing containers..."
docker-compose down

# Build and start containers
echo "🏗️ Building and starting containers..."
docker-compose up --build -d

# Wait for container to start
echo "⏳ Waiting for container to start..."
sleep 10

# Check container status
echo "🔍 Checking container status..."
docker-compose ps

# Test the API
echo "🧪 Testing API endpoints..."
curl -s http://localhost:8080/api/status | jq '.' || echo "API test failed"

echo ""
echo "🎉 Deployment completed!"
echo "🌐 Server URL: http://35.247.182.78:8080"
echo "📊 API Endpoints:"
echo "   - Health Check: http://35.247.182.78:8080/api/status"
echo "   - AI Chat: http://35.247.182.78:8080/api/chat"
echo "   - Device Control: http://35.247.182.78:8080/api/control"
echo ""
echo "🔧 Useful commands:"
echo "   - View logs: docker-compose logs -f"
echo "   - Stop server: docker-compose down"
echo "   - Restart server: docker-compose restart"
echo "   - Update server: docker-compose up --build -d"
