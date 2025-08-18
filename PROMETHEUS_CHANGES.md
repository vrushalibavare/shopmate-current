# Prometheus Monitoring Changes

## Overview
Added comprehensive Prometheus metrics support to ShopMate application for monitoring application performance, business metrics, and Node.js runtime health.

## Dependencies Added
- `prom-client: ^15.1.0` - Prometheus client library for Node.js

## Files Modified

### 1. app/package.json
- Added `prom-client` dependency

### 2. app/app.js
**Added:**
- Prometheus client import and setup
- Default Node.js metrics collection
- HTTP request metrics (counter and histogram)
- Business metrics (orders, cart, products, revenue)
- Custom Node.js metrics (active handles, event loop lag)
- Metrics middleware to track all HTTP requests
- Enhanced `/metrics` endpoint with proper Prometheus format
- Periodic metrics updates (every 5 seconds)

**Metrics exported:**
- `http_requests_total` - Total HTTP requests by method, route, status
- `http_request_duration_seconds` - Request duration histogram
- `orders_created_total` - Total orders created
- `cart_items_added_total` - Total cart additions
- `product_views_total` - Total product views
- `order_value_total` - Total revenue
- `nodejs_active_handles_total` - Active Node.js handles
- `nodejs_eventloop_lag_seconds` - Event loop lag
- Plus all default Node.js metrics (memory, CPU, etc.)

### 3. app/controllers/productController.js
**Added:**
- Metrics import with fallback handling
- Product view tracking in `getAllProducts()` and `getProductDetails()`

### 4. app/controllers/cartController.js
**Added:**
- Metrics import with fallback handling
- Cart item addition tracking in `addToCart()`

### 5. app/controllers/orderController.js
**Added:**
- Metrics import with fallback handling
- Order creation and revenue tracking in `placeOrder()`

## Metrics Available

### HTTP Metrics
- Request count by method, route, and status code
- Request duration percentiles
- Error rates (4xx/5xx responses)

### Business Metrics
- Product page views
- Items added to cart
- Orders created
- Total revenue

### System Metrics
- Memory usage (heap, RSS)
- CPU usage
- Event loop lag
- Active handles/connections
- Process uptime

## Endpoints
- `/metrics` - Prometheus metrics endpoint (text/plain format)

## Usage
1. Prometheus scrapes `/metrics` endpoint
2. Grafana visualizes metrics with dashboards
3. Alerts can be configured based on thresholds

## Testing
Access metrics locally at: `http://localhost:3000/metrics`

## Notes
- Metrics are collected automatically on app startup
- All metrics include proper labels for filtering
- Fallback handling prevents errors if metrics unavailable
- Memory-efficient with periodic cleanup