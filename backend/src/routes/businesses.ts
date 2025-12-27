import express from 'express';
import {
  getAllBusinesses,
  getBusinessById,
  getBusinessStaff,
  getBusinessDashboard,
  getPendingBusinesses,
  reviewBusinessRegistration,
} from '../controllers/businessController';
import { authenticate, authorize } from '../middleware/auth';
import { UserRole } from '../models/User';

const router = express.Router();

// Public routes
router.get('/businesses', getAllBusinesses);
router.get('/businesses/:id', getBusinessById);
router.get('/businesses/:businessId/staff', getBusinessStaff);

// Protected routes
router.get('/business/dashboard', authenticate, getBusinessDashboard);
router.get(
  '/admin/businesses/pending',
  authenticate,
  authorize(UserRole.ADMIN),
  getPendingBusinesses
);
router.post(
  '/admin/businesses/:id/review',
  authenticate,
  authorize(UserRole.ADMIN),
  reviewBusinessRegistration
);

export default router;
