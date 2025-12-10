import express from 'express';
import {
  getBusinessShifts,
  getBusinessStaffMembers,
  createShift,
  updateShift,
  deleteShift,
  getAvailableTimeSlots,
  getStaffShifts,
} from '../controllers/shiftController';
import { authenticate } from '../middleware/auth';

const router = express.Router();

// Public routes for booking
router.get('/available-slots', getAvailableTimeSlots);
router.get('/staff-shifts', getStaffShifts);

// Protected routes
router.get('/', authenticate, getBusinessShifts);
router.get('/staff-members', authenticate, getBusinessStaffMembers);
router.post('/', authenticate, createShift);
router.put('/:id', authenticate, updateShift);
router.delete('/:id', authenticate, deleteShift);

export default router;
