# Complete Caddy Setup Guide

This guide covers the complete setup of Caddy web server for hosting multiple websites and backend services on a VPS with automatic SSL certificates.

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Basic Configuration](#basic-configuration)
4. [Website Setup](#website-setup)
5. [Backend API Setup](#backend-api-setup)
6. [Troubleshooting](#troubleshooting)
7. [Best Practices](#best-practices)

## Overview

### What is Caddy?

Caddy is a modern web server written in Go that provides:
- **Automatic HTTPS**: SSL certificates from Let's Encrypt with zero configuration
- **Simple Configuration**: Human-readable Caddyfile format
- **HTTP/3 Support**: Latest web protocols
- **Zero Dependencies**: Single binary with no external dependencies
- **Production Ready**: Handles millions of certificates and trillions of requests

### Project Structure Overview

This setup includes:
- **Static Websites**: Portfolio, personal sites
- **Backend APIs**: Rust applications with reverse proxy
- **Dashboard**: Frontend applications with CORS configuration
- **Automatic SSL**: Let's Encrypt certificates for all domains

## Installation

### Method 1: Package Installation (Recommended)

For Ubuntu/Debian systems:

```bash
# Install required packages
sudo apt update
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl

# Add Caddy's official repository
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list

# Update package list and install Caddy
sudo apt update
sudo apt install caddy
```

### Method 2: Binary Installation

If package installation fails:

```bash
# Download latest Caddy binary
curl -OL https://github.com/caddyserver/caddy/releases/latest/download/caddy_linux_amd64.tar.gz
tar -xzf caddy_linux_amd64.tar.gz
sudo mv caddy /usr/bin/caddy
sudo chmod +x /usr/bin/caddy

# Give Caddy permission to bind to low ports
sudo setcap cap_net_bind_service=+ep /usr/bin/caddy

# Create caddy user and directories
sudo groupadd --system caddy
sudo useradd --system --gid caddy --create-home --home-dir /var/lib/caddy --shell /usr/sbin/nologin caddy
sudo mkdir -p /etc/caddy
sudo chown -R root:caddy /etc/caddy
```

### Systemd Service Setup

Create the systemd service file:

```bash
sudo tee /etc/systemd/system/caddy.service > /dev/null <<EOF
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=1048576
PrivateTmp=true
ProtectHome=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable Caddy
sudo systemctl daemon-reload
sudo systemctl enable caddy
```

## Basic Configuration

### DNS Setup

For each domain/subdomain, create DNS A records pointing to your VPS IP:

```
portfolio.yourdomain.com     → YOUR_VPS_IP
personal.yourdomain.com      → YOUR_VPS_IP
api.yourdomain.com          → YOUR_VPS_IP
dashboard.yourdomain.com    → YOUR_VPS_IP
```

**Important**: Never use underscores in domain names (e.g., `api_dashboard.com`). Use hyphens instead (`api-dashboard.com`) as SSL certificates don't support underscores.

### Firewall Configuration

Ensure required ports are open:

```bash
# For UFW
sudo ufw allow 80   # HTTP
sudo ufw allow 443  # HTTPS

# For iptables
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
```

### Basic Caddyfile Structure

The Caddyfile is located at `/etc/caddy/Caddyfile`:

```caddy
# Basic syntax
domain.com {
    directive1
    directive2
}

another-domain.com {
    directive1
    directive2
}
```

## Website Setup

### Static Website Configuration

#### File Organization

```bash
# Create directories for static sites
sudo mkdir -p /var/www/portfolio
sudo mkdir -p /var/www/personal

# Copy your website files
sudo cp -r /path/to/your/portfolio/* /var/www/portfolio/
sudo cp -r /path/to/your/personal/* /var/www/personal/

# Set proper permissions
sudo chown -R caddy:caddy /var/www/
sudo chmod -R 755 /var/www/
```

#### Caddyfile Configuration for Static Sites

```caddy
# Portfolio Website
portfolio.blackshadow.software {
    root * /var/www/portfolio
    encode gzip
    file_server
    
    # Security headers
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
    }
}

# Personal Website
personal.blackshadow.software {
    root * /var/www/personal
    encode gzip
    file_server
    
    # Security headers
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
    }
}

# Multiple domains for same site
example.com, www.example.com {
    root * /var/www/html
    encode gzip
    file_server
}
```

#### Single Page Application (SPA) Configuration

For React, Vue, or Angular apps:

```caddy
app.yourdomain.com {
    root * /var/www/app
    encode gzip
    
    # Handle client-side routing
    try_files {path} /index.html
    file_server
    
    # Cache static assets
    @static {
        path *.css *.js *.png *.jpg *.jpeg *.gif *.ico *.svg *.woff *.woff2
    }
    header @static Cache-Control "public, max-age=31536000"
    
    # Don't cache the main HTML file
    header /index.html Cache-Control "public, max-age=0, must-revalidate"
}
```

## Backend API Setup

### Rust Backend Service Setup

#### Create Systemd Service for Backend

```bash
sudo nano /etc/systemd/system/fuel-cost-server.service
```

```ini
[Unit]
Description=Fuel Cost Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/projects/fuel_cost_server
ExecStart=/root/projects/fuel_cost_server/target/release/fuel_cost_server
Restart=on-failure
RestartSec=5
Environment=RUST_LOG=info

[Install]
WantedBy=multi-user.target
```

#### Enable and Start Backend Service

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable and start your backend
sudo systemctl enable fuel-cost-server
sudo systemctl start fuel-cost-server

# Check status
sudo systemctl status fuel-cost-server
```

### API Reverse Proxy Configuration

#### Basic API Proxy

```caddy
# Basic API reverse proxy
api.yourdomain.com {
    reverse_proxy localhost:8880
}
```

#### Advanced API Configuration with CORS

```caddy
# API with CORS support for web applications
fuelcost.blackshadow.software {
    # Handle CORS preflight requests
    @cors_preflight method OPTIONS
    respond @cors_preflight 204

    # CORS headers for all responses
    header {
        Access-Control-Allow-Origin "https://fuelcost-dashboard.blackshadow.software"
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With"
        Access-Control-Allow-Credentials "true"
    }
    
    # Security headers
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
    }
    
    reverse_proxy localhost:8880
}
```

#### API with Load Balancing

```caddy
api.yourdomain.com {
    reverse_proxy {
        to localhost:8880 localhost:8881 localhost:8882
        lb_policy round_robin
        health_check /health
        health_interval 30s
    }
}
```

### Mixed Configuration: Static + API

```caddy
yourdomain.com {
    encode gzip
    
    # API routes go to backend
    handle /api/* {
        reverse_proxy localhost:3000
    }
    
    # Everything else serves static files
    handle {
        root * /var/www/html
        file_server
    }
}
```

## Complete Production Caddyfile Example

Here's the complete Caddyfile used in our setup:

```caddy
# Portfolio Website
portfolio.blackshadow.software {
    root * /var/www/portfolio
    encode gzip
    file_server
    
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
    }
}

# Personal Website
personal.blackshadow.software {
    root * /var/www/personal
    encode gzip
    file_server
    
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
    }
}

# Rust API Backend with CORS
fuelcost.blackshadow.software {
    # Handle CORS preflight requests
    @cors_preflight method OPTIONS
    respond @cors_preflight 204

    # CORS headers
    header {
        Access-Control-Allow-Origin "https://fuelcost-dashboard.blackshadow.software"
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With"
        Access-Control-Allow-Credentials "true"
    }
    
    reverse_proxy localhost:8880
}

# Dashboard Frontend
fuelcost-dashboard.blackshadow.software {
    root * /var/www/fuelcost_dashboard
    encode gzip
    file_server
    
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
    }
}
```

## Troubleshooting

### Common Issues and Solutions

#### 1. DNS Resolution Errors

```bash
# Check DNS propagation
dig +short yourdomain.com
nslookup yourdomain.com

# Should return your VPS IP address
```

#### 2. SSL Certificate Issues

```bash
# Check certificate acquisition logs
sudo journalctl -u caddy | grep -i certificate

# Common issues:
# - Underscore in domain name (use hyphens instead)
# - DNS not pointing to server
# - Firewall blocking ports 80/443
```

#### 3. Permission Issues

```bash
# Fix file permissions
sudo chown -R caddy:caddy /var/www/
sudo chmod -R 755 /var/www/

# Check if caddy can access files
sudo -u caddy cat /var/www/portfolio/index.html
```

#### 4. Service Management Issues

```bash
# Check which caddy binary path is used
which caddy

# Update systemd service if path is wrong
sudo nano /etc/systemd/system/caddy.service
# Update ExecStart and ExecReload paths

# Reload systemd after changes
sudo systemctl daemon-reload
sudo systemctl restart caddy
```

### Useful Commands

```bash
# Validate Caddyfile syntax
sudo caddy validate --config /etc/caddy/Caddyfile

# Reload configuration (no downtime)
sudo systemctl reload caddy

# Restart Caddy service
sudo systemctl restart caddy

# Check service status
sudo systemctl status caddy

# View logs in real-time
sudo journalctl -u caddy -f

# Check listening ports
sudo netstat -tlnp | grep caddy

# Test configuration
curl -I http://yourdomain.com
curl -I https://yourdomain.com
```

### CORS Debugging

```bash
# Test CORS preflight request
curl -X OPTIONS https://api.yourdomain.com/endpoint \
  -H "Origin: https://frontend.yourdomain.com" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type"

# Should return appropriate CORS headers
```

## Best Practices

### Security

1. **Use Strong TLS Settings**:
```caddy
yourdomain.com {
    tls {
        protocols tls1.2 tls1.3
    }
    # ... rest of config
}
```

2. **Security Headers**:
```caddy
header {
    Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    X-Content-Type-Options "nosniff"
    X-Frame-Options "DENY"
    X-XSS-Protection "1; mode=block"
    Referrer-Policy "strict-origin-when-cross-origin"
}
```

3. **Rate Limiting** (requires plugin):
```caddy
rate_limit {
    zone dynamic {
        key {remote_host}
        window 1m
        events 100
    }
}
```

### Performance

1. **Enable Compression**:
```caddy
encode gzip zstd
```

2. **Cache Static Assets**:
```caddy
@static {
    path *.css *.js *.png *.jpg *.jpeg *.gif *.ico *.svg *.woff *.woff2
}
header @static Cache-Control "public, max-age=31536000"
```

3. **Precompressed Files**:
```caddy
file_server {
    precompressed gzip br
}
```

### Monitoring

1. **Access Logs**:
```caddy
log {
    output file /var/log/caddy/access.log
    format json
}
```

2. **Health Checks**:
```caddy
reverse_proxy localhost:8080 {
    health_check /health
    health_interval 30s
}
```

### Backup and Maintenance

1. **Backup Configuration**:
```bash
# Backup Caddyfile
sudo cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d)

# Backup certificates (automatic renewal, but good to backup)
sudo tar -czf caddy-certs-backup.tar.gz /var/lib/caddy/.local/share/caddy/
```

2. **Updates**:
```bash
# Update Caddy (if installed via package)
sudo apt update && sudo apt upgrade caddy

# Or download latest binary
sudo systemctl stop caddy
# Download and replace binary
sudo systemctl start caddy
```

### Environment Variables

Use environment variables for sensitive data:

```bash
# Set environment variable
export API_TOKEN="your-secret-token"
```

```caddy
api.yourdomain.com {
    reverse_proxy localhost:8080 {
        header_up Authorization "Bearer {$API_TOKEN}"
    }
}
```

## Project Structure Summary

```
/etc/caddy/Caddyfile                 # Main configuration
/var/www/                           # Static websites
├── portfolio/                      # Portfolio site files
├── personal/                       # Personal site files
└── fuelcost_dashboard/             # Dashboard files

/root/projects/fuel_cost_server/    # Backend application
└── target/release/fuel_cost_server # Rust binary

/etc/systemd/system/                # Service files
├── caddy.service                   # Caddy web server
└── fuel-cost-server.service        # Backend API service

/var/lib/caddy/                     # Caddy data directory
└── .local/share/caddy/             # SSL certificates
```

## Final Notes

This setup provides:
- ✅ Automatic HTTPS for all domains
- ✅ HTTP/3 support
- ✅ Proper CORS configuration
- ✅ Static file serving with compression
- ✅ Reverse proxy for backend APIs
- ✅ Security headers
- ✅ Automatic certificate renewal
- ✅ Production-ready configuration

The configuration is scalable and can easily accommodate additional websites, APIs, and services by following the same patterns established in this guide.
