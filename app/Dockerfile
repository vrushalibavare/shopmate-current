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