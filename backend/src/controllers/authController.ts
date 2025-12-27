import { Response } from 'express';
import jwt from 'jsonwebtoken';
import { User, Business, StaffMember, BusinessApprovalStatus } from '../models';
import { UserRole, AuthProvider } from '../models/User';
import { AuthRequest } from '../middleware/auth';
import firebaseAdmin from '../config/firebase';

// Generate JWT token
const generateToken = (userId: number, email: string, role: string, firstName?: string, lastName?: string, fullName?: string): string => {
  return jwt.sign(
    { userId, email, role, firstName, lastName, fullName },
    process.env.JWT_SECRET || 'your-secret-key',
    { expiresIn: '7d' }
  );
};

// Register Customer (Local Auth)
export const registerCustomer = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { email, password, firstName, lastName, phone } = req.body;

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

    // Generate token
    const token = generateToken(user.id, user.email, user.role, user.firstName, user.lastName, user.fullName);

    res.status(201).json({
      message: 'Customer registered successfully',
      token,
      user: user.toSafeObject(),
    });
  } catch (error: any) {
    console.error('Register customer error:', error);
    res.status(500).json({ message: 'Error registering customer', error: error.message });
  }
};

// Register Staff (Local Auth)
export const registerStaff = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { email, password, fullName, businessId } = req.body;

    // Check if user already exists
    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) {
      return res.status(400).json({ message: 'Email already registered' });
    }

    // Find business by businessId
    const business = await Business.findOne({ where: { businessId } });
    if (!business) {
      return res.status(404).json({ message: 'Business not found. Please check your Business ID' });
    }
    if (business.approvalStatus !== BusinessApprovalStatus.APPROVED) {
      return res.status(400).json({ message: 'Business is not approved yet. Please try again later.' });
    }

    // Create new staff user
    const user = await User.create({
      email,
      password,
      fullName,
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

    // Generate token
    const token = generateToken(user.id, user.email, user.role, user.firstName, user.lastName, user.fullName);

    res.status(201).json({
      message: 'Staff registered successfully',
      token,
      user: user.toSafeObject(),
      businessName: business.businessName,
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
    if (!email || !password || !fullName || !businessName) {
      console.error('Missing required fields:', { email: !!email, password: !!password, fullName: !!fullName, businessName: !!businessName });
      return res.status(400).json({ message: 'Missing required fields' });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) {
      return res.status(400).json({ message: 'Email already registered' });
    }

    console.log('Creating business owner user...');
    // Create new business owner user
    const user = await User.create({
      email,
      password,
      fullName,
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
      isActive: false,
      approvalStatus: BusinessApprovalStatus.PENDING,
    });

    console.log('Business created:', business.id, business.businessId);

    // Generate token
    const token = generateToken(user.id, user.email, user.role, user.firstName, user.lastName, user.fullName);

    res.status(201).json({
      message: 'Business registered successfully',
      token,
      user: user.toSafeObject(),
      business: {
        id: business.id,
        businessName: business.businessName,
        businessId: business.businessId,
      },
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
          isActive: false,
          approvalStatus: BusinessApprovalStatus.PENDING,
        });
      } else if (role === UserRole.STAFF && additionalData?.businessId) {
        const business = await Business.findOne({ where: { businessId: additionalData.businessId } });
        if (business && business.approvalStatus === BusinessApprovalStatus.APPROVED) {
          await StaffMember.create({
            userId: user.id,
            businessId: business.id,
            isActive: true,
          });
        } else if (!business) {
          return res.status(404).json({ message: 'Business not found. Please check your Business ID.' });
        } else {
          return res.status(400).json({ message: 'Business is not approved yet. Please try again later.' });
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
