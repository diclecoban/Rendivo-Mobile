import express from 'express';
import {
  getAllBusinesses,
  getBusinessById,
  getBusinessStaff,
  getBusinessDashboard,
  getBusinessAvailability,
  removeStaffMember,
  sendBusinessTestNotification,
} from '../controllers/businessController';
import { authenticate } from '../middleware/auth';

const router = express.Router();

// Public routes
router.get('/businesses', getAllBusinesses);
router.get('/businesses/:id', getBusinessById);
router.get('/businesses/:businessId/staff', getBusinessStaff);
router.get('/businesses/:id/availability', getBusinessAvailability);

// Protected routes
router.get('/business/dashboard', authenticate, getBusinessDashboard);
router.delete('/business/staff/:id', authenticate, removeStaffMember);
router.post('/businesses/:businessId/test-push', authenticate, sendBusinessTestNotification);

export default router;
