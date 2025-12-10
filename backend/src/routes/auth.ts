import express from 'express';
import {
  registerCustomer,
  registerStaff,
  registerBusiness,
  login,
  firebaseAuth,
  getProfile,
  logout,
} from '../controllers/authController';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validation';
import {
  registerCustomerValidation,
  registerStaffValidation,
  registerBusinessValidation,
  loginValidation,
  firebaseAuthValidation,
} from '../middleware/validators';

const router = express.Router();

// Local Authentication Routes
router.post('/register/customer', validate(registerCustomerValidation), registerCustomer);
router.post('/register/staff', validate(registerStaffValidation), registerStaff);
router.post('/register/business', validate(registerBusinessValidation), registerBusiness);
router.post('/login', validate(loginValidation), login);

// Firebase Authentication Route
router.post('/firebase', validate(firebaseAuthValidation), firebaseAuth);

// Protected Routes
router.get('/profile', authenticate, getProfile);
router.post('/logout', authenticate, logout);

export default router;
