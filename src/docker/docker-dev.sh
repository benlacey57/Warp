#!/bin/bash
# Docker Development Environment Manager

set -e

# Load core utilities
WARP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$WARP_DIR/src/core/logger.sh"
source "$WARP_DIR/src/core/utils.sh"

PROJECT_ROOT=$(pwd)
PROJECT_NAME=$(basename "$PROJECT_ROOT")

# Create Docker Compose for Python project
create_python_docker() {
    log_info "Creating Python Docker development environment..."
    
    # Dockerfile
    cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements*.txt ./

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements-dev.txt

# Copy application code
COPY . .

# Install package in development mode
RUN pip install -e .

# Expose port
EXPOSE 8000

# Default command
CMD ["python", "-m", "src.main"]
EOF
    
    # docker-compose.yml
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - .:/app
      - python_cache:/root/.cache/pip
    environment:
      - PYTHONPATH=/app/src
      - DEBUG=1
    command: python -m src.$PROJECT_NAME.main
    
  redis:
    image: redis:alpine
    ports:
      - "6379:6379"
    
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: $PROJECT_NAME
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  python_cache:
  postgres_data:
EOF
    
    # .dockerignore
    cat > .dockerignore << 'EOF'
.git
.venv
venv/
__pycache__
*.pyc
.pytest_cache
.coverage
.DS_Store
node_modules
EOF
    
    # Development helper script
    cat > docker-dev.sh << 'EOF'
#!/bin/bash
# Docker development helper

case "$1" in
    "start")
        echo "🚀 Starting Python development environment..."
        docker-compose up -d
        echo "✅ Environment started!"
        echo "🐍 App: http://localhost:8000"
        echo "🗄️  PostgreSQL: localhost:5432"
        echo "📦 Redis: localhost:6379"
        ;;
    "stop")
        echo "🛑 Stopping development environment..."
        docker-compose down
        ;;
    "logs")
        docker-compose logs -f app
        ;;
    "shell")
        docker-compose exec app bash
        ;;
    "test")
        docker-compose exec app pytest
        ;;
    "quality")
        docker-compose exec app bash -c "warp quality"
        ;;
    *)
        echo "Python Docker Development Helper"
        echo "Usage: ./docker-dev.sh {start|stop|logs|shell|test|quality}"
        ;;
esac
EOF
    
    chmod +x docker-dev.sh
    
    log_success "Python Docker environment created"
    echo "🚀 Start with: ./docker-dev.sh start"
}

# Create Docker Compose for JavaScript project
create_javascript_docker() {
    log_info "Creating JavaScript Docker development environment..."
    
    # Dockerfile
    cat > Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache git

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy application code
COPY . .

# Expose port
EXPOSE 3000

# Default command
CMD ["npm", "run", "dev"]
EOF
    
    # docker-compose.yml
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    volumes:
      - .:/app
      - /app/node_modules
    environment:
      - NODE_ENV=development
    command: npm run dev
    
  redis:
    image: redis:alpine
    ports:
      - "6379:6379"
    
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: $PROJECT_NAME
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
EOF
    
    # .dockerignore
    cat > .dockerignore << 'EOF'
.git
node_modules
npm-debug.log
.nyc_output
coverage
.DS_Store
EOF
    
    # Development helper script
    cat > docker-dev.sh << 'EOF'
#!/bin/bash
# Docker development helper

case "$1" in
    "start")
        echo "🚀 Starting JavaScript development environment..."
        docker-compose up -d
        echo "✅ Environment started!"
        echo "🌐 App: http://localhost:3000"
        echo "🗄️  PostgreSQL: localhost:5432"
        echo "📦 Redis: localhost:6379"
        ;;
    "stop")
        echo "🛑 Stopping development environment..."
        docker-compose down
        ;;
    "logs")
        docker-compose logs -f app
        ;;
    "shell")
        docker-compose exec app sh
        ;;
    "test")
        docker-compose exec app npm test
        ;;
    "quality")
        docker-compose exec app bash -c "warp quality"
        ;;
    *)
        echo "JavaScript Docker Development Helper"
        echo "Usage: ./docker-dev.sh {start|stop|logs|shell|test|quality}"
        ;;
esac
EOF
    
    chmod +x docker-dev.sh
    
    log_success "JavaScript Docker environment created"
    echo "🚀 Start with: ./docker-dev.sh start"
}

# Create WordPress development environment
create_wordpress_docker() {
    local plugin_name="$1"
    
    log_info "Creating WordPress development environment..."
    
    # docker-compose.yml
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  wordpress:
    image: wordpress:latest
    ports:
      - "8080:80"
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DEBUG: 1
    volumes:
      - wordpress_data:/var/www/html
      - .:/var/www/html/wp-content/plugins/$plugin_name
    depends_on:
      - db
    networks:
      - wordpress-network

  db:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress
      MYSQL_ROOT_PASSWORD: rootpassword
    volumes:
      - db_data:/var/lib/mysql
    ports:
      - "3306:3306"
    networks:
      - wordpress-network

  phpmyadmin:
    image: phpmyadmin:latest
    ports:
      - "8081:80"
    environment:
      PMA_HOST: db
      PMA_USER: wordpress
      PMA_PASSWORD: wordpress
    depends_on:
      - db
    networks:
      - wordpress-network

  wp-cli:
    image: wordpress:cli
    volumes:
      - wordpress_data:/var/www/html
      - .:/var/www/html/wp-content/plugins/$plugin_name
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress
      WORDPRESS_DB_NAME: wordpress
    depends_on:
      - db
      - wordpress
    networks:
      - wordpress-network

volumes:
  wordpress_data:
  db_data:

networks:
  wordpress-network:
    driver: bridge
EOF
    
    # WordPress development helper script
    cat > wp-dev.sh << EOF
#!/bin/bash
# WordPress development helper

case "\$1" in
    "start")
        echo "🚀 Starting WordPress development environment..."
        docker-compose up -d
        
        echo "⏳ Waiting for WordPress to be ready..."
        sleep 30
        
        # Install WordPress
        docker-compose run --rm wp-cli wp core install \\
            --url=http://localhost:8080 \\
            --title="WordPress Development" \\
            --admin_user=admin \\
            --admin_password=admin \\
            --admin_email=admin@localhost.dev
        
        # Activate plugin
        docker-compose run --rm wp-cli wp plugin activate $plugin_name
        
        echo "✅ WordPress environment ready!"
        echo "🌐 WordPress: http://localhost:8080"
        echo "👤 Admin: http://localhost:8080/wp-admin (admin/admin)"
        echo "🗄️  phpMyAdmin: http://localhost:8081"
        ;;
    "stop")
        echo "🛑 Stopping WordPress development environment..."
        docker-compose down
        ;;
    "restart")
        echo "🔄 Restarting WordPress development environment..."
        docker-compose down
        docker-compose up -d
        ;;
    "logs")
        docker-compose logs -f wordpress
        ;;
    "wp")
        shift
        docker-compose run --rm wp-cli wp "\$@"
        ;;
    "activate")
        echo "🔌 Activating plugin: $plugin_name"
        docker-compose run --rm wp-cli wp plugin activate $plugin_name
        ;;
    "deactivate")
        echo "🔌 Deactivating plugin: $plugin_name"
        docker-compose run --rm wp-cli wp plugin deactivate $plugin_name
        ;;
    "quality")
        echo "🔍 Running quality checks..."
        warp quality
        ;;
    "security")
        echo "🔒 Running security checks..."
        warp security
        ;;
    *)
        echo "WordPress Development Helper"
        echo "Usage: ./wp-dev.sh {start|stop|restart|logs|wp|activate|deactivate|quality|security}"
        echo
        echo "Examples:"
        echo "  ./wp-dev.sh start     # Start WordPress environment"
        echo "  ./wp-dev.sh wp --info # Run WP-CLI command"
        echo "  ./wp-dev.sh activate  # Activate the plugin"
        ;;
esac
EOF
    
    chmod +x wp-dev.sh
    
    log_success "WordPress Docker environment created"
    echo "🚀 Start with: ./wp-dev.sh start"
}

# Main function
main() {
    case "$1" in
        "setup")
            local project_type="$2"
            
            if [[ -z "$project_type" ]]; then
                # Auto-detect project type
                if [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]]; then
                    project_type="python"
                elif [[ -f "package.json" ]]; then
                    project_type="javascript"
                elif find . -maxdepth 1 -name "*.php" -exec grep -l "Plugin Name:" {} \; 2>/dev/null | head -1 | grep -q .; then
                    project_type="wordpress-plugin"
                else
                    log_error "Cannot auto-detect project type"
                    echo "Usage: warp docker setup <type>"
                    echo "Types: python, javascript, wordpress-plugin"
                    exit 1
                fi
            fi
            
            log_info "Setting up Docker environment for: $project_type"
            
            case "$project_type" in
                "python")
                    create_python_docker
                    ;;
                "javascript"|"node")
                    create_javascript_docker
                    ;;
                "wordpress-plugin")
                    create_wordpress_docker "$PROJECT_NAME"
                    ;;
                *)
                    log_error "Unsupported project type: $project_type"
                    exit 1
                    ;;
            esac
            ;;
        *)
            echo "Docker Development Environment Manager"
            echo "Usage: warp docker setup [type]"
            echo
            echo "Project types:"
            echo "  python           - Python application with PostgreSQL and Redis"
            echo "  javascript       - Node.js application with PostgreSQL and Redis"
            echo "  wordpress-plugin - WordPress with MySQL and phpMyAdmin"
            echo
            echo "Examples:"
            echo "  warp docker setup python    # Setup Python environment"
            echo "  warp docker setup           # Auto-detect and setup"
            ;;
    esac
}

main "$@"
