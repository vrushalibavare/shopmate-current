# ============================================================================
# DEVELOPMENT DOCKERFILE
# ============================================================================
# Development image with enhanced debugging capabilities
#
# Base Image: node:18-alpine
# - Full Node.js Alpine Linux environment
# - Package manager (apk) available for installing debug tools
# - Busybox shell (sh) for interactive debugging
# - More debugging tools and utilities available
# - Larger image size but full development flexibility
#
# Use Case: Development environment where debugging access is needed
# Security: Moderate - has shell access but Alpine is minimal
# ============================================================================
FROM node:18-alpine

WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm ci && npm cache clean --force

# Copy application code
COPY . .

EXPOSE 3000

# Use node directly for better signal handling
CMD ["node", "app.js"]