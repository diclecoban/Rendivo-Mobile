import { Response } from 'express';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { User, Business, StaffMember } from '../models';
import { UserRole, AuthProvider } from '../models/User';
import { ApprovalStatus } from '../models/Business';
import { AuthRequest } from '../middleware/auth';
import firebaseAdmin from '../config/firebase';
import EmailService from '../services/emailService';

// Password validation function
const validatePassword = (
  password: string
): { valid: boolean; message?: string } => {
  if (!password || password.length < 8) {
    return {
      valid: false,
      message: 'Password must be at least 8 characters long',
    };
  }

  const hasLetter = /[a-zA-Z]/.test(password);
  const hasNumber = /[0-9]/.test(password);

  if (!hasLetter || !hasNumber) {
    return {
      valid: false,
      message: 'Password must contain both letters and numbers',
    };
  }

  return { valid: true };
};

// Generate JWT token
const generateToken = (userId: number, email: string, role: string, firstName?: string, lastName?: string, fullName?: string): string => {
  return jwt.sign(
    { userId, email, role, firstName, lastName, fullName },
    process.env.JWT_SECRET || 'your-secret-key',
    { expiresIn: '7d' }
  );
};

const resetCodeTtlMinutes = Number(process.env.RESET_CODE_TTL_MINUTES || 15);
const resetCodeSecret =
  process.env.RESET_CODE_SECRET ||
  process.env.JWT_SECRET ||
  'reset-code-secret';

const resetCodeWindowMs = resetCodeTtlMinutes * 60 * 1000;
const verifyCodeTtlMinutes = Number(
  process.env.VERIFY_CODE_TTL_MINUTES || 24 * 60
);
const verifyCodeSecret =
  process.env.VERIFY_CODE_SECRET ||
  process.env.JWT_SECRET ||
  'verify-code-secret';
const verifyCodeWindowMs = verifyCodeTtlMinutes * 60 * 1000;

const generateResetCode = (email: string, window: number): string => {
  const hmac = crypto.createHmac('sha256', resetCodeSecret);
  hmac.update(`${email.toLowerCase()}|${window}`);
  const hex = hmac.digest('hex');
  const value = parseInt(hex.slice(0, 8), 16) % 1000000;
  return value.toString().padStart(6, '0');
};

const isResetCodeValid = (email: string, code: string): boolean => {
  const window = Math.floor(Date.now() / resetCodeWindowMs);
  const current = generateResetCode(email, window);
  const previous = generateResetCode(email, window - 1);
  return code === current || code === previous;
};

const generateVerifyCode = (email: string, window: number): string => {
  const hmac = crypto.createHmac('sha256', verifyCodeSecret);
  hmac.update(`${email.toLowerCase()}|${window}`);
  const hex = hmac.digest('hex');
  const value = parseInt(hex.slice(0, 8), 16) % 1000000;
  return value.toString().padStart(6, '0');
};

const isVerifyCodeValid = (email: string, code: string): boolean => {
  const window = Math.floor(Date.now() / verifyCodeWindowMs);
  const current = generateVerifyCode(email, window);
  const previous = generateVerifyCode(email, window - 1);
  return code === current || code === previous;
};

// Register Customer (Local Auth)
export const registerCustomer = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { email, password, firstName, lastName, phone } = req.body;

    // Validate password
    const passwordValidation = validatePassword(password);
    if (!passwordValidation.valid) {
      return res.status(400).json({ message: passwordValidation.message });
    }

    console.log('🔍 Backend - Received email:', email);
    console.log('🔍 Backend - Email type:', typeof email);
    console.log('🔍 Backend - Email length:', email?.length);

    // Check if user already exists
    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) {
      return res.status(400).json({ message: 'Email already registered' });
    }

    // Create new customer
    const user = await User.create({
      email,
      password,
      firstName,
      lastName,
      phone,
      role: UserRole.CUSTOMER,
      authProvider: AuthProvider.LOCAL,
      emailVerified: false,
      isActive: true,
    });

    // Send verification email
    try {
      const window = Math.floor(Date.now() / verifyCodeWindowMs);
      const code = generateVerifyCode(user.email, window);
      await EmailService.sendVerificationEmail(user.email, code);
    } catch (emailError) {
      console.error('Failed to send verification email:', emailError);
      // Continue anyway - user is created
    }

    res.status(201).json({
      message: 'Customer registered successfully. Please check your email to verify your account.',
      user: user.toSafeObject(),
      emailSent: true,
    });
  } catch (error: any) {
    console.error('Register customer error:', error);
    res.status(500).json({ message: 'Error registering customer', error: error.message });
  }
};

// Register Staff (Local Auth)
export const registerStaff = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { email, password, fullName, firstName, lastName, businessId } = req.body;

    if (!email || !password || !businessId) {
      return res.status(400).json({
        message: 'All fields are required: email, password, businessId',
      });
    }

    const resolvedFullName =
      fullName || [firstName, lastName].filter(Boolean).join(' ');
    if (!resolvedFullName) {
      return res.status(400).json({
        message: 'Full name or first/last name is required',
      });
    }

    // Validate password
    const passwordValidation = validatePassword(password);
    if (!passwordValidation.valid) {
      return res.status(400).json({ message: passwordValidation.message });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) {
      return res.status(400).json({ message: 'Email already registered' });
    }

    // Find business by businessId (join code) or numeric id
    const parsedId = Number(businessId);
    const business = Number.isFinite(parsedId) && parsedId > 0
      ? await Business.findByPk(parsedId)
      : await Business.findOne({ where: { businessId } });
    if (!business) {
      return res.status(404).json({ message: 'Business not found. Please check your Business ID' });
    }

    // Create new staff user
    const user = await User.create({
      email,
      password,
      fullName: resolvedFullName,
      firstName,
      lastName,
      role: UserRole.STAFF,
      authProvider: AuthProvider.LOCAL,
      emailVerified: false,
      isActive: true,
    });

    // Create staff member association
    await StaffMember.create({
      userId: user.id,
      businessId: business.id,
      isActive: true,
    });

    // Send verification email
    try {
      const window = Math.floor(Date.now() / verifyCodeWindowMs);
      const code = generateVerifyCode(user.email, window);
      await EmailService.sendVerificationEmail(user.email, code);
    } catch (emailError) {
      console.error('Failed to send verification email:', emailError);
    }

    // Send welcome notification to staff
    try {
      const { notificationService } = await import('../services/notificationService');
      await notificationService.sendNotification({
        userId: user.id.toString(),
        type: 'staff_added',
        title: '🎉 Welcome to the Team!',
        message: `You've been added to ${business.businessName}! We're excited to have you on board! 💙`,
        relatedId: business.id.toString(),
        relatedType: 'appointment',
        actionUrl: `/staff-dashboard`,
        emailData: {
          to: user.email,
          subject: '🎉 Welcome to the Team!',
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
              <h2 style="color: #333; border-bottom: 3px solid #007bff; padding-bottom: 10px;">🎉 Welcome Aboard!</h2>
              <p style="color: #555; line-height: 1.6;">Hi ${resolvedFullName}! 👋</p>
              <p style="color: #555; line-height: 1.6;">Exciting news! You've been added as a staff member at <strong>${business.businessName}</strong>! 🌟</p>
              <div style="background-color: white; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #007bff;">
                <p style="margin: 5px 0;"><strong>🏢 Business:</strong> ${business.businessName}</p>
                <p style="margin: 5px 0;"><strong>📧 Your Email:</strong> ${user.email}</p>
                <p style="margin: 5px 0;"><strong>🔑 Your Role:</strong> Staff Member</p>
              </div>
              <p style="color: #555; line-height: 1.6;">Please verify your email to get started. Once verified, you'll be able to:</p>
              <ul style="color: #555; line-height: 1.6;">
                <li>View your schedule and appointments</li>
                <li>Manage your availability</li>
                <li>Connect with customers</li>
              </ul>
              <p style="color: #555; line-height: 1.6;">We're thrilled to have you on the team! Let's do amazing work together! 💙</p>
              <p style="color: #999; font-size: 12px; margin-top: 30px;">Welcome to the family! 🎉</p>
            </div>
          `,
        },
      });

      // Send notification to business owner about new staff
      const businessOwner = await User.findByPk(business.ownerId);
      if (businessOwner) {
        await notificationService.sendNotification({
          userId: business.ownerId.toString(),
          type: 'staff_added',
          title: '👥 New Team Member!',
          message: `${resolvedFullName} has joined your team at ${business.businessName}! 🎉`,
          relatedId: business.id.toString(),
          relatedType: 'appointment',
          actionUrl: `/business/staff`,
          emailData: {
            to: businessOwner.email,
            subject: '👥 New Team Member Joined!',
            html: `
              <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
                <h2 style="color: #333; border-bottom: 3px solid #007bff; padding-bottom: 10px;">👥 Team Update!</h2>
                <p style="color: #555; line-height: 1.6;">Hello! 👋</p>
                <p style="color: #555; line-height: 1.6;">Great news! A new staff member has joined your team! 🎉</p>
                <div style="background-color: white; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #007bff;">
                  <p style="margin: 5px 0;"><strong>👤 New Staff:</strong> ${resolvedFullName}</p>
                  <p style="margin: 5px 0;"><strong>📧 Email:</strong> ${user.email}</p>
                  <p style="margin: 5px 0;"><strong>🏢 Business:</strong> ${business.businessName}</p>
                </div>
                <p style="color: #555; line-height: 1.6;">They'll need to verify their email before accessing the platform. Once verified, they'll be ready to:</p>
                <ul style="color: #555; line-height: 1.6;">
                  <li>View their schedule and appointments</li>
                  <li>Manage their availability</li>
                  <li>Serve your customers</li>
                </ul>
                <p style="color: #555; line-height: 1.6;">Your team is growing! Keep up the great work! 💙</p>
                <p style="color: #999; font-size: 12px; margin-top: 30px;">Your business is thriving! 🌟</p>
              </div>
            `,
          },
        });
      }
    } catch (notifError) {
      console.error('Failed to send welcome notification:', notifError);
    }

    res.status(201).json({
      message: 'Staff registered successfully. Please check your email to verify your account.',
      user: user.toSafeObject(),
      businessName: business.businessName,
      emailSent: true,
    });
  } catch (error: any) {
    console.error('Register staff error:', error);
    res.status(500).json({ message: 'Error registering staff', error: error.message });
  }
};

// Register Business Owner (Multi-step)
export const registerBusiness = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    console.log('Register business request body:', req.body);
    
    const { 
      email, 
      password, 
      fullName,
      firstName,
      lastName,
      businessName, 
      businessType,
      address,
      city,
      state,
      zipCode,
      phone,
      website 
    } = req.body;

    // Validate required fields
    const resolvedFullName =
      fullName || [firstName, lastName].filter(Boolean).join(' ');
    if (!email || !password || !resolvedFullName || !businessName) {
      console.error('Missing required fields:', { email: !!email, password: !!password, fullName: !!resolvedFullName, businessName: !!businessName });
      return res.status(400).json({ message: 'Missing required fields' });
    }

    // Validate password
    const passwordValidation = validatePassword(password);
    if (!passwordValidation.valid) {
      return res.status(400).json({ message: passwordValidation.message });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) {
      // Check if user has a rejected business - allow reapplication
      const existingBusiness = await Business.findOne({ 
        where: { ownerId: existingUser.id } 
      });
      
      if (existingBusiness && existingBusiness.approvalStatus === 'rejected') {
        console.log('🔄 Reapplication from rejected business owner:', email);
        
        // Update existing business with new information
        await existingBusiness.update({
          businessName,
          businessType,
          address,
          city,
          state,
          zipCode,
          phone,
          website,
          approvalStatus: ApprovalStatus.PENDING,
          isActive: true,
          rejectionReason: undefined,
        });
        
        await existingUser.update({
          fullName: resolvedFullName,
          firstName,
          lastName,
          password,
          isActive: true,
          emailVerified: false,
        });
        
        // Send verification email
        try {
          const window = Math.floor(Date.now() / verifyCodeWindowMs);
          const code = generateVerifyCode(existingUser.email, window);
          await EmailService.sendVerificationEmail(existingUser.email, code);
        } catch (emailError) {
          console.error('Failed to send verification email:', emailError);
        }
        
        return res.json({
          user: {
            id: existingUser.id,
            email: existingUser.email,
            fullName: existingUser.fullName,
            role: existingUser.role,
          },
          business: existingBusiness,
          approvalStatus: existingBusiness.approvalStatus,
          message: 'Reapplication submitted successfully. Please verify your email.'
        });
      }
      
      return res.status(400).json({ message: 'Email already registered' });
    }

    console.log('Creating business owner user...');
    // Create new business owner user
    const user = await User.create({
      email,
      password,
      fullName: resolvedFullName,
      firstName,
      lastName,
      role: UserRole.BUSINESS_OWNER,
      authProvider: AuthProvider.LOCAL,
      emailVerified: false,
      isActive: true,
    });

    console.log('User created:', user.id);
    console.log('Creating business...');

    // Create business
    const business = await Business.create({
      ownerId: user.id,
      businessName,
      businessType,
      address,
      city,
      state,
      zipCode,
      phone,
      email,
      website,
      isActive: true,
    });

    console.log('Business created:', business.id, business.businessId);

    // Send verification email
    try {
      const window = Math.floor(Date.now() / verifyCodeWindowMs);
      const code = generateVerifyCode(user.email, window);
      await EmailService.sendVerificationEmail(user.email, code);
    } catch (emailError) {
      console.error('Failed to send verification email:', emailError);
    }

    res.status(201).json({
      message: 'Business registered successfully. Please check your email to verify your account.',
      user: user.toSafeObject(),
      business: {
        id: business.id,
        businessName: business.businessName,
        businessId: business.businessId,
        approvalStatus: business.approvalStatus,
      },
      approvalStatus: business.approvalStatus,
      emailSent: true,
    });
  } catch (error: any) {
    console.error('Register business error:', error);
    res.status(500).json({ message: 'Error registering business', error: error.message });
  }
};

// Login (Local Auth)
export const login = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { email, password } = req.body;

    // Find user by email
    const user = await User.findOne({ where: { email } });
    if (!user) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    // Check if account is active
    if (!user.isActive) {
      return res.status(403).json({ message: 'Account is deactivated' });
    }

    // Check password
    const isPasswordValid = await user.comparePassword(password);
    if (!isPasswordValid) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    // Check if email is verified
    if (!user.emailVerified) {
      return res.status(403).json({ 
        message: 'Email not verified. Please check your email for the verification link.',
        emailVerified: false,
        email: user.email
      });
    }

    // Update last login
    user.lastLogin = new Date();
    await user.save();

    // Generate token
    const token = generateToken(user.id, user.email, user.role, user.firstName, user.lastName, user.fullName);

    // Get additional data based on role
    let additionalData: any = {};
    if (user.role === UserRole.BUSINESS_OWNER) {
      const business = await Business.findOne({ where: { ownerId: user.id } });
      additionalData.business = business;
      additionalData.approvalStatus = business?.approvalStatus;
    } else if (user.role === UserRole.STAFF) {
      const staffMembership = await StaffMember.findOne({ 
        where: { userId: user.id },
        include: [{ model: Business, as: 'business' }]
      });
      additionalData.staffMembership = staffMembership;
    }

    res.status(200).json({
      message: 'Login successful',
      token,
      user: user.toSafeObject(),
      ...additionalData,
    });
  } catch (error: any) {
    console.error('Login error:', error);
    res.status(500).json({ message: 'Error during login', error: error.message });
  }
};

// Firebase Authentication
export const firebaseAuth = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { firebaseToken, role, additionalData } = req.body;

    if (!firebaseAdmin) {
      return res.status(500).json({ message: 'Firebase is not configured' });
    }

    // Verify Firebase token
    const decodedToken = await firebaseAdmin.auth().verifyIdToken(firebaseToken);
    const { uid, email, name } = decodedToken;

    if (!email) {
      return res.status(400).json({ message: 'Email is required from Firebase token' });
    }

    // Check if user exists
    let user = await User.findOne({ where: { firebaseUid: uid } });

    if (!user) {
      // Check if email exists with different auth provider
      user = await User.findOne({ where: { email } });
      
      if (user && user.authProvider !== AuthProvider.FIREBASE) {
        return res.status(400).json({ 
          message: 'Email already registered with different authentication method' 
        });
      }

      // Create new user
      user = await User.create({
        email,
        fullName: name || additionalData?.fullName,
        firstName: additionalData?.firstName,
        lastName: additionalData?.lastName,
        phone: additionalData?.phone,
        role: role as UserRole,
        authProvider: AuthProvider.FIREBASE,
        firebaseUid: uid,
        emailVerified: decodedToken.email_verified || false,
        isActive: true,
      });

      // Handle business or staff registration
      if (role === UserRole.BUSINESS_OWNER && additionalData?.businessName) {
        await Business.create({
          ownerId: user.id,
          businessName: additionalData.businessName,
          businessType: additionalData.businessType,
          isActive: true,
        });
      } else if (role === UserRole.STAFF && additionalData?.businessId) {
        const business = await Business.findOne({ where: { businessId: additionalData.businessId } });
        if (business) {
          await StaffMember.create({
            userId: user.id,
            businessId: business.id,
            isActive: true,
          });
        }
      }
    }

    // Update last login
    user.lastLogin = new Date();
    await user.save();

    // Generate JWT token
    const token = generateToken(user.id, user.email, user.role, user.firstName, user.lastName, user.fullName);

    res.status(200).json({
      message: 'Firebase authentication successful',
      token,
      user: user.toSafeObject(),
    });
  } catch (error: any) {
    console.error('Firebase auth error:', error);
    res.status(500).json({ message: 'Error during Firebase authentication', error: error.message });
  }
};

// Get current user profile
export const getProfile = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const userId = req.user.id;

    const user = await User.findByPk(userId, {
      attributes: { exclude: ['password'] }
    });

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    let additionalData: any = {};
    if (user.role === UserRole.BUSINESS_OWNER) {
      const business = await Business.findOne({ where: { ownerId: user.id } });
      additionalData.business = business;
    } else if (user.role === UserRole.STAFF) {
      const staffMembership = await StaffMember.findOne({ 
        where: { userId: user.id },
        include: [{ model: Business, as: 'business' }]
      });
      additionalData.staffMembership = staffMembership;
    }

    res.status(200).json({
      user: user.toSafeObject(),
      ...additionalData,
    });
  } catch (error: any) {
    console.error('Get profile error:', error);
    res.status(500).json({ message: 'Error fetching profile', error: error.message });
  }
};

// Logout (optional - mainly for token blacklisting if implemented)
export const logout = async (_req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    // In a stateless JWT setup, logout is handled client-side by removing the token
    // If you implement token blacklisting, add logic here
    
    res.status(200).json({
      message: 'Logout successful',
    });
  } catch (error: any) {
    console.error('Logout error:', error);
    res.status(500).json({ message: 'Error during logout', error: error.message });
  }
};

// Request Password Reset Code
export const requestPasswordReset = async (
  req: AuthRequest,
  res: Response
): Promise<Response | void> => {
  try {
    const { email } = req.body;
    const user = await User.findOne({
      where: { email },
      attributes: ['id', 'email', 'password'],
    });

    if (!user || !user.password) {
      return res.status(200).json({
        message: 'If an account exists, a reset code has been sent.',
      });
    }

    const window = Math.floor(Date.now() / resetCodeWindowMs);
    const code = generateResetCode(user.email, window);

    await EmailService.sendPasswordResetCode(user.email, code);

    return res.status(200).json({
      message: 'If an account exists, a reset code has been sent.',
    });
  } catch (error: any) {
    console.error('Request password reset error:', error);
    return res.status(500).json({
      message: 'Error requesting password reset',
      error: error.message,
    });
  }
};

// Confirm Password Reset Code
export const confirmPasswordReset = async (
  req: AuthRequest,
  res: Response
): Promise<Response | void> => {
  try {
    const { email, code, password } = req.body;
    const user = await User.findOne({
      where: { email },
      attributes: ['id', 'email'],
    });

    if (!user) {
      return res.status(400).json({ message: 'Invalid reset code' });
    }

    if (!isResetCodeValid(user.email, code)) {
      return res.status(400).json({ message: 'Invalid reset code' });
    }
 
    user.password = password;
    await user.save();

    return res.status(200).json({ message: 'Password reset successful' });
  } catch (error: any) {
    console.error('Confirm password reset error:', error);
    return res.status(500).json({
      message: 'Error resetting password',
      error: error.message,
    });
  }
};

// Verify Email
export const verifyEmail = async (
  req: AuthRequest,
  res: Response
): Promise<Response | void> => {
  try {
    const email = (req.query.email ?? req.body?.email ?? '').toString().trim();
    const code = (
      req.query.code ??
      req.params.token ??
      req.body?.code ??
      ''
    )
      .toString()
      .trim();

    if (!email || !code) {
      return res.status(400).json({ message: 'Email and code are required' });
    }

    const user = await User.findOne({ where: { email } });
    if (!user) {
      return res.status(400).json({ message: 'Invalid or expired verification code' });
    }

    if (user.emailVerified) {
      return res.status(400).json({ message: 'Email is already verified' });
    }

    if (!isVerifyCodeValid(user.email, code)) {
      return res.status(400).json({ message: 'Invalid or expired verification code' });
    }

    user.emailVerified = true;
    await user.save();

    try {
      await EmailService.sendWelcomeEmail(user.email, user.fullName || user.firstName);
    } catch (emailError) {
      console.error('Failed to send welcome email:', emailError);
    }

    return res.status(200).json({
      message: 'Email verified successfully! You can now log in.',
      emailVerified: true,
    });
  } catch (error: any) {
    console.error('Verify email error:', error);
    return res.status(500).json({ message: 'Error verifying email', error: error.message });
  }
};

// Resend Verification Email
export const resendVerification = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { email } = req.body;

    // Find user by email
    const user = await User.findOne({ where: { email } });

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Check if already verified
    if (user.emailVerified) {
      return res.status(400).json({ message: 'Email is already verified' });
    }

    const window = Math.floor(Date.now() / verifyCodeWindowMs);
    const code = generateVerifyCode(user.email, window);
    await EmailService.sendVerificationEmail(user.email, code);

    res.status(200).json({
      message: 'Verification email sent successfully. Please check your inbox.',
      emailSent: true,
    });
  } catch (error: any) {
    console.error('Resend verification error:', error);
    res.status(500).json({ message: 'Error sending verification email', error: error.message });
  }
};
