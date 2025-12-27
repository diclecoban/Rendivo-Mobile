-- Migration: Add approval status columns to businesses table
-- Date: 2025-12-14

-- Add approval status column
ALTER TABLE businesses 
ADD COLUMN approvalStatus ENUM('pending', 'approved', 'rejected') NOT NULL DEFAULT 'pending' AFTER businessId;

-- Add approved at timestamp column
ALTER TABLE businesses 
ADD COLUMN approvedAt DATETIME NULL AFTER approvalStatus;

-- Add rejection reason column
ALTER TABLE businesses 
ADD COLUMN rejectionReason TEXT NULL AFTER approvedAt;

-- Update existing businesses to 'approved' status (so they continue working)
UPDATE businesses 
SET approvalStatus = 'approved', 
    approvedAt = NOW() 
WHERE approvalStatus = 'pending';
