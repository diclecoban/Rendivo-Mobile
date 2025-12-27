#!/bin/bash

# Run database migration for approval columns
# Make sure your .env file has the correct database credentials

echo "Running database migration: add-approval-columns.sql"

# Load environment variables
source backend/.env

# Run migration
mysql \
  --host=$DB_HOST \
  --port=$DB_PORT \
  --user=$DB_USER \
  --password=$DB_PASSWORD \
  --ssl-mode=REQUIRED \
  $DB_NAME < backend/migrations/add-approval-columns.sql

echo "Migration completed!"
