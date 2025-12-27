import express from 'express';
import { authenticate } from '../middleware/auth';
import {
  createAppointment,
  getCustomerAppointments,
  getBusinessAppointments,
  getStaffAppointments,
  getAppointmentById,
  updateAppointmentStatus,
  cancelAppointment,
  rescheduleAppointment,
} from '../controllers/appointmentController';

const router = express.Router();

// All routes are protected
router.post('/appointments', authenticate, createAppointment);
router.get('/appointments', authenticate, getCustomerAppointments);
router.get('/appointments/:id', authenticate, getAppointmentById);
router.delete('/appointments/:id', authenticate, cancelAppointment);
router.patch('/appointments/:id/reschedule', authenticate, rescheduleAppointment);

// Business owner routes
router.get('/business/appointments', authenticate, getBusinessAppointments);
router.patch('/business/appointments/:id/status', authenticate, updateAppointmentStatus);

// Staff member routes
router.get('/staff/appointments', authenticate, getStaffAppointments);

export default router;
