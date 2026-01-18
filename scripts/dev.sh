#!/bin/bash

# Development startup script for Acquisition App with Neon Local
# This script starts the application in development mode with Neon Local

echo "🚀 Starting Acquisition App in Development Mode"
echo "================================================"

# Check if .env.development exists
if [ ! -f .env.development ]; then
    echo "❌ Error: .env.development file not found!"
    echo "   Please copy .env.development from the template and update with your Neon credentials."
    exit 1
fi

# Load .env.development for required values
set -a
. ./.env.development
set +a

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Error: Docker is not running!"
    echo "   Please start Docker Desktop and try again."
    exit 1
fi

# Create .neon_local directory if it doesn't exist
mkdir -p .neon_local

# Add .neon_local to .gitignore if not already present
if ! grep -q ".neon_local/" .gitignore 2>/dev/null; then
    echo ".neon_local/" >> .gitignore
    echo "✅ Added .neon_local/ to .gitignore"
fi

if [ -z "$NEON_API_KEY" ] || [ -z "$NEON_PROJECT_ID" ]; then
    echo "❌ Error: NEON_API_KEY or NEON_PROJECT_ID is missing in .env.development"
    echo "   Neon Local needs both to create or reuse a branch."
    exit 1
fi

if [ -z "$DATABASE_URL" ]; then
    echo "❌ Error: DATABASE_URL is missing in .env.development"
    exit 1
fi

compose_cmd="docker compose -f docker-compose.dev.yml --env-file .env.development"

echo "📦 Building and starting development containers..."
echo "   - Neon Local proxy will create an ephemeral database branch"
echo "   - Application will run with hot reload enabled"
echo ""

# Start Neon Local first
$compose_cmd up -d --build neon-local

# Wait for the database to be ready
echo "⏳ Waiting for the database to be ready..."
db_ready=false
for i in {1..30}; do
    if $compose_cmd exec -T neon-local pg_isready -h localhost -p 5432 -U neon -d neondb >/dev/null 2>&1; then
        db_ready=true
        break
    fi
    sleep 2
done

if [ "$db_ready" != "true" ]; then
    echo "❌ Error: Neon Local failed to become ready."
    echo "   Check your NEON credentials or run: $compose_cmd logs neon-local"
    exit 1
fi

# Run migrations with Drizzle
echo "📜 Applying latest schema with Drizzle..."
$compose_cmd run --rm app npm run db:migrate

# Start development environment
$compose_cmd up --build

echo ""
echo "🎉 Development environment started!"
echo "   Application: http://localhost:3000"
echo "   Database: postgres://neon:npg@localhost:5432/neondb"
echo ""
echo "To stop the environment, press Ctrl+C or run: docker compose down"
