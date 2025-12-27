import { Response } from 'express';
import { AuthRequest } from '../middleware/auth';
import { Business, User } from '../models';
import { ApprovalStatus } from '../models/Business';

// Get all pending business approvals
export const getPendingBusinesses = async (_req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const businesses = await Business.findAll({
      where: {
        approvalStatus: ApprovalStatus.PENDING,
      },
      include: [
        {
          model: User,
          as: 'owner',
          attributes: ['id', 'email', 'fullName', 'phone', 'createdAt'],
        },
      ],
      order: [['createdAt', 'DESC']],
    });

    res.json(businesses);
  } catch (error: any) {
    console.error('Get pending businesses error:', error);
    res.status(500).json({ message: 'Error fetching pending businesses', error: error.message });
  }
};

// Get all businesses with filters
export const getAllBusinessesAdmin = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { status } = req.query;

    const whereClause: any = {};
    if (status && typeof status === 'string') {
      whereClause.approvalStatus = status;
    }

    const businesses = await Business.findAll({
      where: whereClause,
      include: [
        {
          model: User,
          as: 'owner',
          attributes: ['id', 'email', 'fullName', 'phone', 'createdAt'],
        },
      ],
      order: [['createdAt', 'DESC']],
    });

    res.json(businesses);
  } catch (error: any) {
    console.error('Get all businesses admin error:', error);
    res.status(500).json({ message: 'Error fetching businesses', error: error.message });
  }
};

// Approve a business
export const approveBusiness = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { id } = req.params;

    const business = await Business.findByPk(id, {
      include: [
        {
          model: User,
          as: 'owner',
          attributes: ['id', 'email', 'fullName'],
        },
      ],
    });

    if (!business) {
      return res.status(404).json({ message: 'Business not found' });
    }

    if (business.approvalStatus !== ApprovalStatus.PENDING) {
      return res.status(400).json({ message: `Business is already ${business.approvalStatus}` });
    }

    await business.update({
      approvalStatus: ApprovalStatus.APPROVED,
      approvedAt: new Date(),
    });

    // TODO: Send approval email to business owner
    // This would use the email service (Nodemailer) when implemented

    res.json({
      message: 'Business approved successfully',
      business,
    });
  } catch (error: any) {
    console.error('Approve business error:', error);
    res.status(500).json({ message: 'Error approving business', error: error.message });
  }
};

// Reject a business
export const rejectBusiness = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { id } = req.params;
    const { reason } = req.body;

    if (!reason || reason.trim() === '') {
      return res.status(400).json({ message: 'Rejection reason is required' });
    }

    const business = await Business.findByPk(id, {
      include: [
        {
          model: User,
          as: 'owner',
          attributes: ['id', 'email', 'fullName'],
        },
      ],
    });

    if (!business) {
      return res.status(404).json({ message: 'Business not found' });
    }

    if (business.approvalStatus !== ApprovalStatus.PENDING) {
      return res.status(400).json({ message: `Business is already ${business.approvalStatus}` });
    }

    await business.update({
      approvalStatus: ApprovalStatus.REJECTED,
      isActive: false,
    });

    // TODO: Send rejection email to business owner with reason
    // This would use the email service (Nodemailer) when implemented

    res.json({
      message: 'Business rejected successfully',
      business,
    });
  } catch (error: any) {
    console.error('Reject business error:', error);
    res.status(500).json({ message: 'Error rejecting business', error: error.message });
  }
};

// Get business details (admin view)
export const getBusinessDetails = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { id } = req.params;

    const business = await Business.findByPk(id, {
      include: [
        {
          model: User,
          as: 'owner',
          attributes: ['id', 'email', 'fullName', 'phone', 'createdAt', 'lastLogin'],
        },
      ],
    });

    if (!business) {
      return res.status(404).json({ message: 'Business not found' });
    }

    res.json(business);
  } catch (error: any) {
    console.error('Get business details error:', error);
    res.status(500).json({ message: 'Error fetching business details', error: error.message });
  }
};

// Get dashboard stats for admin
export const getAdminStats = async (_req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const totalBusinesses = await Business.count();
    const pendingBusinesses = await Business.count({
      where: { approvalStatus: ApprovalStatus.PENDING },
    });
    const approvedBusinesses = await Business.count({
      where: { approvalStatus: ApprovalStatus.APPROVED },
    });
    const rejectedBusinesses = await Business.count({
      where: { approvalStatus: ApprovalStatus.REJECTED },
    });

    const totalUsers = await User.count();
    const totalCustomers = await User.count({
      where: { role: 'customer' },
    });
    const totalStaff = await User.count({
      where: { role: 'staff' },
    });

    res.json({
      businesses: {
        total: totalBusinesses,
        pending: pendingBusinesses,
        approved: approvedBusinesses,
        rejected: rejectedBusinesses,
      },
      users: {
        total: totalUsers,
        customers: totalCustomers,
        staff: totalStaff,
      },
    });
  } catch (error: any) {
    console.error('Get admin stats error:', error);
    res.status(500).json({ message: 'Error fetching admin stats', error: error.message });
  }
};
