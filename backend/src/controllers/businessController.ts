import { Response } from 'express';
import { AuthRequest } from '../middleware/auth';
import { Business, User, StaffMember, Service, Appointment, BusinessApprovalStatus } from '../models';
import { Op, QueryTypes } from 'sequelize';
import sequelize from '../config/database';

// Get all active businesses (for discover page)
export const getAllBusinesses = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { search, services } = req.query;

    const whereClause: any = {
      isActive: true,
      approvalStatus: BusinessApprovalStatus.APPROVED,
    };

    // Search by business name or type
    if (search && typeof search === 'string') {
      whereClause[Op.or] = [
        { businessName: { [Op.like]: `%${search}%` } },
        { businessType: { [Op.like]: `%${search}%` } },
      ];
    }

    const businesses = await Business.findAll({
      where: whereClause,
      attributes: ['id', 'businessId', 'businessName', 'businessType', 'address', 'city', 'state', 'phone', 'email', 'logo'],
      include: [
        {
          model: Service,
          as: 'services',
          where: { isActive: true },
          attributes: ['id', 'name', 'price', 'duration'],
          required: false,
        },
      ],
      order: [['businessName', 'ASC']],
    });

    // Filter by services if provided
    let filteredBusinesses = businesses;
    if (services && typeof services === 'string') {
      const serviceNames = services.split(',').map(s => s.trim().toLowerCase());
      filteredBusinesses = businesses.filter(business => {
        const businessServices = (business as any).services || [];
        return businessServices.some((service: any) =>
          serviceNames.some(name => service.name.toLowerCase().includes(name))
        );
      });
    }

    res.json(filteredBusinesses);
  } catch (error: any) {
    console.error('Get all businesses error:', error);
    res.status(500).json({ message: 'Error fetching businesses', error: error.message });
  }
};

// Get business by ID with details
export const getBusinessById = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { id } = req.params;

    const business = await Business.findByPk(id, {
      attributes: ['id', 'businessId', 'businessName', 'businessType', 'description', 'address', 'city', 'state', 'zipCode', 'phone', 'email', 'website', 'logo'],
      include: [
        {
          model: Service,
          as: 'services',
          where: { isActive: true },
          attributes: ['id', 'name', 'description', 'price', 'duration'],
          required: false,
        },
        {
          model: StaffMember,
          as: 'staff',
          where: { isActive: true },
          attributes: ['id', 'position', 'userId', 'businessId', 'isActive', 'joinedAt'],
          include: [
            {
              model: User,
              as: 'user',
              attributes: ['id', 'firstName', 'lastName', 'fullName', 'email', 'phone'],
            },
          ],
          required: false,
        },
      ],
    });

    if (!business) {
      return res.status(404).json({ message: 'Business not found' });
    }

    res.json(business);
  } catch (error: any) {
    console.error('Get business by ID error:', error);
    res.status(500).json({ message: 'Error fetching business', error: error.message });
  }
};

// Get staff for a business
export const getBusinessStaff = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { businessId } = req.params;

    const staff = await StaffMember.findAll({
      where: {
        businessId,
        isActive: true,
      },
      attributes: ['id', 'position', 'userId', 'businessId', 'isActive', 'joinedAt'],
      include: [
        {
          model: User,
          as: 'user',
          attributes: ['id', 'firstName', 'lastName', 'fullName', 'email', 'phone'],
        },
      ],
    });

    res.json(staff);
  } catch (error: any) {
    console.error('Get business staff error:', error);
    res.status(500).json({ message: 'Error fetching staff', error: error.message });
  }
};

// Get business dashboard statistics
export const getBusinessDashboard = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ message: 'User not authenticated' });
    }

    // Get business owned by the user
    const business = await Business.findOne({
      where: { ownerId: userId },
    });

    if (!business) {
      return res.status(404).json({ message: 'Business not found' });
    }

    if (business.approvalStatus !== BusinessApprovalStatus.APPROVED) {
      return res.status(200).json({
        status:
          business.approvalStatus === BusinessApprovalStatus.PENDING
            ? 'pending_approval'
            : 'rejected',
        business: {
          id: business.id,
          name: business.businessName,
          approvalStatus: business.approvalStatus,
          submittedAt: business.createdAt,
          approvedAt: business.approvedAt,
          rejectedAt: business.rejectedAt,
          reviewNotes: business.reviewNotes,
        },
        message:
          business.approvalStatus === BusinessApprovalStatus.PENDING
            ? 'Business is awaiting admin approval.'
            : 'Business registration was rejected. Please contact support.',
      });
    }

    const businessId = business.id;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    const startOfWeek = new Date(today);
    startOfWeek.setDate(today.getDate() - today.getDay());

    const lastWeekStart = new Date(startOfWeek);
    lastWeekStart.setDate(lastWeekStart.getDate() - 7);
    const lastWeekEnd = new Date(startOfWeek);

    // Get upcoming appointments (today and future)
    const upcomingAppointments = await Appointment.findAll({
      where: {
        businessId,
        appointmentDate: { [Op.gte]: today },
        status: { [Op.in]: ['pending', 'confirmed'] },
      },
      include: [
        {
          model: User,
          as: 'customer',
          attributes: ['id', 'firstName', 'lastName', 'fullName', 'email'],
        },
        {
          model: StaffMember,
          as: 'staff',
          attributes: ['id', 'position'],
          include: [
            {
              model: User,
              as: 'user',
              attributes: ['firstName', 'lastName', 'fullName'],
            },
          ],
        },
        {
          model: Service,
          as: 'services',
          attributes: ['id', 'name', 'price', 'duration'],
          through: { attributes: [] },
        },
      ],
      order: [['appointmentDate', 'ASC'], ['startTime', 'ASC']],
    });

    // Count total appointments (all time)
    const totalAppointments = await Appointment.count({
      where: {
        businessId,
        status: { [Op.in]: ['pending', 'confirmed', 'completed'] },
      },
    });

    // Count today's appointments
    const todayCount = await Appointment.count({
      where: {
        businessId,
        appointmentDate: today,
        status: { [Op.in]: ['pending', 'confirmed'] },
      },
    });
    const yesterdayCount = await Appointment.count({
      where: {
        businessId,
        appointmentDate: yesterday,
        status: { [Op.in]: ['pending', 'confirmed'] },
      },
    });

    // Count new clients this week
    const thisWeekClients = await Appointment.count({
      where: {
        businessId,
        appointmentDate: { [Op.gte]: startOfWeek },
        status: { [Op.in]: ['pending', 'confirmed', 'completed'] },
      },
      distinct: true,
      col: 'customerId',
    });

    const lastWeekClients = await Appointment.count({
      where: {
        businessId,
        appointmentDate: { [Op.between]: [lastWeekStart, lastWeekEnd] },
        status: { [Op.in]: ['pending', 'confirmed', 'completed'] },
      },
      distinct: true,
      col: 'customerId',
    });

    // Calculate projected revenue from upcoming appointments
    const projectedRevenue = upcomingAppointments.reduce((sum, apt) => sum + parseFloat(apt.totalPrice.toString()), 0);
    
    // Calculate yesterday's revenue for comparison
    const yesterdayAppointments = await Appointment.findAll({
      where: {
        businessId,
        appointmentDate: yesterday,
        status: { [Op.in]: ['pending', 'confirmed', 'completed'] },
      },
    });
    const yesterdayRevenue = yesterdayAppointments.reduce((sum, apt) => sum + parseFloat(apt.totalPrice.toString()), 0);
    
    // Calculate today's completed revenue for comparison
    const todayCompletedRevenue = await Appointment.findAll({
      where: {
        businessId,
        appointmentDate: today,
        status: { [Op.in]: ['confirmed', 'completed'] },
      },
    });
    const todayRevenue = todayCompletedRevenue.reduce((sum, apt) => sum + parseFloat(apt.totalPrice.toString()), 0);

    // Get staff availability (current status from appointments)
    const staff = await StaffMember.findAll({
      where: { businessId, isActive: true },
      include: [
        {
          model: User,
          as: 'user',
          attributes: ['id', 'firstName', 'lastName', 'fullName'],
        },
      ],
    });

    const currentTime = new Date();
    const staffWithStatus = await Promise.all(staff.map(async (member) => {
      const currentAppointment = await Appointment.findOne({
        where: {
          businessId,
          staffId: member.id,
          appointmentDate: today,
          status: { [Op.in]: ['confirmed', 'pending'] },
        },
        order: [['startTime', 'ASC']],
      });

      let status = 'available';
      if (currentAppointment) {
        const startTime = new Date(`${today.toISOString().split('T')[0]}T${currentAppointment.startTime}`);
        const endTime = new Date(`${today.toISOString().split('T')[0]}T${currentAppointment.endTime}`);
        if (currentTime >= startTime && currentTime <= endTime) {
          status = 'busy';
        }
      }

      return {
        id: member.id,
        name: (member as any).user?.fullName || (member as any).user?.firstName || 'Staff',
        status,
        position: member.position,
      };
    }));

    // Get popular services (based on appointment count)
    const serviceStats = await sequelize.query(`
      SELECT s.id, s.name, COUNT(*) as count, 
             (COUNT(*) * 100.0 / (SELECT COUNT(*) FROM appointment_services WHERE appointmentId IN 
               (SELECT id FROM appointments WHERE businessId = :businessId AND appointmentDate >= :startOfWeek)
             )) as percentage
      FROM services s
      JOIN appointment_services aps ON s.id = aps.serviceId
      JOIN appointments a ON aps.appointmentId = a.id
      WHERE a.businessId = :businessId AND a.appointmentDate >= :startOfWeek
      GROUP BY s.id, s.name
      ORDER BY count DESC
      LIMIT 4
    `, {
      replacements: { businessId, startOfWeek },
      type: QueryTypes.SELECT,
    });

    // Calculate percentage changes
    const appointmentChange = yesterdayCount > 0 ? ((todayCount - yesterdayCount) / yesterdayCount * 100).toFixed(1) : '0';
    const clientChange = lastWeekClients > 0 ? ((thisWeekClients - lastWeekClients) / lastWeekClients * 100).toFixed(1) : '0';
    const revenueChange = yesterdayRevenue > 0 ? ((todayRevenue - yesterdayRevenue) / yesterdayRevenue * 100).toFixed(1) : '0';

    res.json({
      status: 'ready',
      business: {
        id: business.id,
        name: business.businessName,
      },
      stats: {
        todayAppointments: totalAppointments,
        appointmentChange: `${parseFloat(appointmentChange) > 0 ? '+' : ''}${appointmentChange}`,
        newClientsThisWeek: thisWeekClients,
        clientChange: `${parseFloat(clientChange) > 0 ? '+' : ''}${clientChange}`,
        projectedRevenue: projectedRevenue.toFixed(2),
        revenueChange: `${parseFloat(revenueChange) > 0 ? '+' : ''}${revenueChange}`,
      },
      upcomingAppointments: upcomingAppointments.map((apt: any) => ({
        id: apt.id,
        service: apt.services?.[0]?.name || 'Service',
        staff: apt.staff?.user?.fullName || apt.staff?.user?.firstName || 'Staff',
        client: apt.customer?.fullName || `${apt.customer?.firstName} ${apt.customer?.lastName}` || apt.customer?.email || 'Client',
        time: apt.startTime,
        status: apt.status,
      })),
      staff: staffWithStatus,
      popularServices: serviceStats,
    });
  } catch (error: any) {
    console.error('Get business dashboard error:', error);
    res.status(500).json({ message: 'Error fetching dashboard data', error: error.message });
  }
};

export const getPendingBusinesses = async (_req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const businesses = await Business.findAll({
      where: { approvalStatus: BusinessApprovalStatus.PENDING },
      include: [
        {
          model: User,
          as: 'owner',
          attributes: ['id', 'fullName', 'firstName', 'lastName', 'email', 'phone'],
        },
      ],
      order: [['createdAt', 'ASC']],
    });

    res.json(businesses);
  } catch (error: any) {
    console.error('Get pending businesses error:', error);
    res.status(500).json({ message: 'Error fetching pending businesses', error: error.message });
  }
};

export const reviewBusinessRegistration = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { id } = req.params;
    const { decision, notes } = req.body;
    const normalizedDecision = typeof decision === 'string' ? decision.toLowerCase() : '';

    if (!['approve', 'reject'].includes(normalizedDecision)) {
      return res.status(400).json({ message: 'Decision must be either "approve" or "reject".' });
    }

    const business = await Business.findByPk(id, {
      include: [
        {
          model: User,
          as: 'owner',
          attributes: ['id', 'fullName', 'firstName', 'lastName', 'email', 'phone'],
        },
      ],
    });

    if (!business) {
      return res.status(404).json({ message: 'Business not found.' });
    }

    if (business.approvalStatus !== BusinessApprovalStatus.PENDING) {
      return res.status(400).json({ message: 'This business has already been reviewed.' });
    }

    business.reviewedBy = req.user?.id ?? null;
    business.reviewNotes = notes;

    if (normalizedDecision === 'approve') {
      business.approvalStatus = BusinessApprovalStatus.APPROVED;
      business.approvedAt = new Date();
      business.rejectedAt = null;
      business.isActive = true;
    } else {
      business.approvalStatus = BusinessApprovalStatus.REJECTED;
      business.rejectedAt = new Date();
      business.approvedAt = null;
      business.isActive = false;
    }

    await business.save();

    res.json({
      message: `Business ${normalizedDecision}d successfully.`,
      business,
    });
  } catch (error: any) {
    console.error('Review business registration error:', error);
    res.status(500).json({ message: 'Error reviewing business registration', error: error.message });
  }
};
