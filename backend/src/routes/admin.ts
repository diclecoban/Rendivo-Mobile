import express from 'express';
import { authenticate, authorize } from '../middleware/auth';
import {
  getPendingBusinesses,
  getAllBusinessesAdmin,
  approveBusiness,
  rejectBusiness,
  reviewBusinessApplication,
  getBusinessDetails,
  getAdminStats,
} from '../controllers/adminController';

const router = express.Router();

// All admin routes require authentication and admin role
router.use(authenticate);
router.use(authorize('admin'));

// Get dashboard stats
router.get('/stats', getAdminStats);

// Get all businesses with optional status filter
router.get('/businesses', getAllBusinessesAdmin);

// Get pending businesses
router.get('/businesses/pending', getPendingBusinesses);

// Get business details
router.get('/businesses/:id', getBusinessDetails);

// Approve a business
router.patch('/businesses/:id/approve', approveBusiness);

// Reject a business
router.patch('/businesses/:id/reject', rejectBusiness);

// Combined review route (approve/reject based on payload)
router.post('/businesses/:id/review', reviewBusinessApplication);

export default router;
