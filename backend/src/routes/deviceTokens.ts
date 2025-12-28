import express from 'express';
import { authenticate } from '../middleware/auth';
import {
  deleteDeviceToken,
  registerDeviceToken,
} from '../controllers/deviceTokenController';

const router = express.Router();

router.post('/device-token', authenticate, registerDeviceToken);
router.delete('/device-token', authenticate, deleteDeviceToken);

export default router;
