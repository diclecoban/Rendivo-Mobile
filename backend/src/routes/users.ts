import express from 'express';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validation';
import { deviceTokenDeleteValidation, deviceTokenValidation } from '../middleware/validators';
import { deleteDeviceToken, registerDeviceToken } from '../controllers/userController';

const router = express.Router();

router.post(
  '/users/device-token',
  authenticate,
  validate(deviceTokenValidation),
  registerDeviceToken
);

router.delete(
  '/users/device-token',
  authenticate,
  validate(deviceTokenDeleteValidation),
  deleteDeviceToken
);

export default router;
