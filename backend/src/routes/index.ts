import express from 'express';
import authRoutes from './auth';
import serviceRoutes from './services';
import appointmentRoutes from './appointments';
import businessRoutes from './businesses';
import shiftRoutes from './shifts';
import adminRoutes from './admin';

const router = express.Router();

// Mount routes
router.use('/auth', authRoutes);
router.use('/', serviceRoutes);
router.use('/', appointmentRoutes);
router.use('/', businessRoutes);
router.use('/shifts', shiftRoutes);
router.use('/admin', adminRoutes);

// Health check endpoint
router.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok', message: 'Server is running' });
});

export default router;
