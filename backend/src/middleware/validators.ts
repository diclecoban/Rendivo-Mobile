import { body } from 'express-validator';

export const registerCustomerValidation = [
  body('email').isEmail().normalizeEmail().withMessage('Please provide a valid email'),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters long'),
  body('firstName').trim().notEmpty().withMessage('First name is required'),
  body('lastName').trim().notEmpty().withMessage('Last name is required'),
  body('phone').optional().trim(),
];

export const registerStaffValidation = [
  body('email').isEmail().normalizeEmail().withMessage('Please provide a valid email'),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters long'),
  body('fullName').trim().notEmpty().withMessage('Full name is required'),
  body('businessId').trim().notEmpty().withMessage('Business ID is required'),
];

export const registerBusinessValidation = [
  body('email').isEmail().normalizeEmail().withMessage('Please provide a valid email'),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters long'),
  body('fullName').trim().notEmpty().withMessage('Full name is required'),
  body('businessName').trim().notEmpty().withMessage('Business name is required'),
  body('businessType').optional().trim(),
];

export const loginValidation = [
  body('email').isEmail().normalizeEmail().withMessage('Please provide a valid email'),
  body('password').notEmpty().withMessage('Password is required'),
];

export const firebaseAuthValidation = [
  body('firebaseToken').notEmpty().withMessage('Firebase token is required'),
  body('role').isIn(['customer', 'staff', 'business_owner']).withMessage('Valid role is required'),
];

export const passwordResetRequestValidation = [
  body('email').isEmail().normalizeEmail().withMessage('Please provide a valid email'),
];

export const passwordResetConfirmValidation = [
  body('email').isEmail().normalizeEmail().withMessage('Please provide a valid email'),
  body('code').isLength({ min: 4 }).withMessage('Reset code is required'),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters long'),
];
