#!/bin/bash

# Smart Home Server Deployment Script for Google Cloud Run
# Usage: ./deploy.sh [PROJECT_ID] [REGION]

set -e

# Configuration
PROJECT_ID=${1:-"your-project-id-here"}
REGION=${2:-"asia-southeast1"}
SERVICE_NAME="smart-home-server"
IMAGE_NAME="gcr.io/$PROJECT_ID/$SERVICE_NAME"

echo "🚀 Starting deployment to Google Cloud Run..."
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Service Name: $SERVICE_NAME"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ Google Cloud CLI is not installed. Please install it first:"
    echo "https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install it first:"
    echo "https://docs.docker.com/get-docker/"
    exit 1
fi

# Authenticate with Google Cloud
echo "🔐 Authenticating with Google Cloud..."
gcloud auth login --no-launch-browser

# Set project
echo "📋 Setting project to $PROJECT_ID..."
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "🔌 Enabling required APIs..."
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# Configure Docker for gcloud
echo "🐳 Configuring Docker for Google Cloud..."
gcloud auth configure-docker

# Build and push Docker image
echo "🏗️ Building Docker image..."
docker build -t $IMAGE_NAME .

echo "📤 Pushing image to Google Container Registry..."
docker push $IMAGE_NAME

# Deploy to Cloud Run
echo "🚀 Deploying to Cloud Run..."
gcloud run deploy $SERVICE_NAME \
    --image $IMAGE_NAME \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated \
    --port 8080 \
    --memory 1Gi \
    --cpu 1 \
    --max-instances 10 \
    --timeout 300 \
    --concurrency 80 \
    --set-env-vars="NODE_ENV=production" \
    --set-env-vars="PORT=8080"

# Get service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format='value(status.url)')

echo "✅ Deployment completed successfully!"
echo "🌐 Service URL: $SERVICE_URL"
echo "📡 API Endpoints:"
echo "   - Health Check: $SERVICE_URL/api/status"
echo "   - Chat AI: $SERVICE_URL/api/chat"
echo "   - Devices: $SERVICE_URL/api/devices"
echo "   - Commands: $SERVICE_URL/api/commands"

echo ""
echo "🔧 Next steps:"
echo "1. Set environment variables in Google Cloud Console:"
echo "   - OPENAI_API_KEY"
echo "   - MQTT_BROKER"
echo "   - MQTT_PORT"
echo "2. Update ESP32 with new MQTT server URL"
echo "3. Test the API endpoints"
echo "4. Create Android app to connect to this server"

echo ""
echo "🎯 Test your deployment:"
echo "curl $SERVICE_URL/api/status"
