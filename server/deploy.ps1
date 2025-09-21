# Smart Home Server Deployment Script for Google Cloud Run (PowerShell)
# Usage: .\deploy.ps1 [PROJECT_ID] [REGION]

param(
    [string]$ProjectId = "your-project-id-here",
    [string]$Region = "asia-southeast1"
)

# Configuration
$ServiceName = "smart-home-server"
$ImageName = "gcr.io/$ProjectId/$ServiceName"

Write-Host "🚀 Starting deployment to Google Cloud Run..." -ForegroundColor Green
Write-Host "Project ID: $ProjectId" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host "Service Name: $ServiceName" -ForegroundColor Yellow

# Check if gcloud is installed
try {
    $null = Get-Command gcloud -ErrorAction Stop
} catch {
    Write-Host "❌ Google Cloud CLI is not installed. Please install it first:" -ForegroundColor Red
    Write-Host "https://cloud.google.com/sdk/docs/install" -ForegroundColor Cyan
    exit 1
}

# Check if docker is installed
try {
    $null = Get-Command docker -ErrorAction Stop
} catch {
    Write-Host "❌ Docker is not installed. Please install it first:" -ForegroundColor Red
    Write-Host "https://docs.docker.com/get-docker/" -ForegroundColor Cyan
    exit 1
}

# Authenticate with Google Cloud
Write-Host "🔐 Authenticating with Google Cloud..." -ForegroundColor Blue
gcloud auth login --no-launch-browser

# Set project
Write-Host "📋 Setting project to $ProjectId..." -ForegroundColor Blue
gcloud config set project $ProjectId

# Enable required APIs
Write-Host "🔌 Enabling required APIs..." -ForegroundColor Blue
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# Configure Docker for gcloud
Write-Host "🐳 Configuring Docker for Google Cloud..." -ForegroundColor Blue
gcloud auth configure-docker

# Build and push Docker image
Write-Host "🏗️ Building Docker image..." -ForegroundColor Blue
docker build -t $ImageName .

Write-Host "📤 Pushing image to Google Container Registry..." -ForegroundColor Blue
docker push $ImageName

# Deploy to Cloud Run
Write-Host "🚀 Deploying to Cloud Run..." -ForegroundColor Blue
gcloud run deploy $ServiceName `
    --image $ImageName `
    --platform managed `
    --region $Region `
    --allow-unauthenticated `
    --port 8080 `
    --memory 1Gi `
    --cpu 1 `
    --max-instances 10 `
    --timeout 300 `
    --concurrency 80 `
    --set-env-vars="NODE_ENV=production" `
    --set-env-vars="PORT=8080"

# Get service URL
$ServiceUrl = gcloud run services describe $ServiceName --region=$Region --format='value(status.url)'

Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
Write-Host "🌐 Service URL: $ServiceUrl" -ForegroundColor Cyan
Write-Host "📡 API Endpoints:" -ForegroundColor Yellow
Write-Host "   - Health Check: $ServiceUrl/api/status" -ForegroundColor White
Write-Host "   - Chat AI: $ServiceUrl/api/chat" -ForegroundColor White
Write-Host "   - Devices: $ServiceUrl/api/devices" -ForegroundColor White
Write-Host "   - Commands: $ServiceUrl/api/commands" -ForegroundColor White

Write-Host ""
Write-Host "🔧 Next steps:" -ForegroundColor Yellow
Write-Host "1. Set environment variables in Google Cloud Console:" -ForegroundColor White
Write-Host "   - OPENAI_API_KEY" -ForegroundColor White
Write-Host "   - MQTT_BROKER" -ForegroundColor White
Write-Host "   - MQTT_PORT" -ForegroundColor White
Write-Host "2. Update ESP32 with new MQTT server URL" -ForegroundColor White
Write-Host "3. Test the API endpoints" -ForegroundColor White
Write-Host "4. Create Android app to connect to this server" -ForegroundColor White

Write-Host ""
Write-Host "🎯 Test your deployment:" -ForegroundColor Yellow
Write-Host "curl $ServiceUrl/api/status" -ForegroundColor Cyan
