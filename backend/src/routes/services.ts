import express from 'express';
import { authenticate } from '../middleware/auth';
import {
  getAllUniqueServices,
  getBusinessServices,
  getOwnerServices,
  createService,
  updateService,
  deleteService,
} from '../controllers/serviceController';

const router = express.Router();

// Public routes
router.get('/businesses/:businessId/services', getBusinessServices);
router.get('/services/all-unique', getAllUniqueServices);
// Protected routes (Business owner)
router.get('/services', authenticate, getOwnerServices);
router.post('/services', authenticate, createService);
router.put('/services/:id', authenticate, updateService);
router.delete('/services/:id', authenticate, deleteService);

export default router;
