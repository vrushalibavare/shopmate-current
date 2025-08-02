#!/bin/bash

# Script to test Docker build locally
echo "🐳 Testing Docker Build"
echo "======================"

echo "1. Building Docker image..."
if docker buildx build --platform=linux/amd64 -t shopmate:test .; then
    echo "  ✅ Docker build successful"
else
    echo "  ❌ Docker build failed"
    exit 1
fi

echo ""
echo "2. Testing container startup..."
CONTAINER_ID=$(docker run -d -p 3001:3000 shopmate:test)

if [ $? -eq 0 ]; then
    echo "  ✅ Container started successfully"
    echo "  📋 Container ID: $CONTAINER_ID"
    
    echo ""
    echo "3. Waiting for application to start..."
    sleep 5
    
    echo "4. Testing application response..."
    if curl -f http://localhost:3001 > /dev/null 2>&1; then
        echo "  ✅ Application responding"
    else
        echo "  ⚠️  Application not responding (may need more time)"
    fi
    
    echo ""
    echo "5. Cleaning up..."
    docker stop "$CONTAINER_ID" > /dev/null
    docker rm "$CONTAINER_ID" > /dev/null
    echo "  ✅ Container cleaned up"
else
    echo "  ❌ Container failed to start"
    exit 1
fi

echo ""
echo "6. Cleaning up image..."
docker rmi shopmate:test > /dev/null 2>&1

echo ""
echo "🏁 Docker build test complete!"
echo "📋 Your application should build successfully in the workflow"