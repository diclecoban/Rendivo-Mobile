import { Response } from 'express';
import { AuthRequest } from '../middleware/auth';
import { Business, User, StaffMember, Service, Appointment, Shift } from '../models';
import { Op, QueryTypes } from 'sequelize';
import sequelize from '../config/database';
import { notificationService } from '../services/notificationService';
import { AppointmentStatus } from '../models/Appointment';

// Get all active businesses (for discover page)
export const getAllBusinesses = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { search, services, businessType } = req.query;

    const whereClause: any = {
      isActive: true,
      approvalStatus: 'approved',
    };

    // Filter by business type (category)
    if (businessType && typeof businessType === 'string') {
      whereClause.businessType = businessType;
    }

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
    let businessId: number;
    
    // If businessId is in params, use it (public route)
    if (req.params.businessId) {
      businessId = parseInt(req.params.businessId);
    } 
    // Otherwise, get business of authenticated user (protected route)
    else if (req.user?.id) {
      const business = await Business.findOne({
        where: { ownerId: req.user.id, isActive: true },
      });
      
      if (!business) {
        return res.status(404).json({ message: 'Business not found' });
      }
      
      businessId = business.id;
    } else {
      return res.status(400).json({ message: 'Business ID required' });
    }

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
      where: { ownerId: userId, isActive: true },
    });

    if (!business) {
      return res.status(404).json({ message: 'Business not found' });
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
        status: { [Op.in]: ['confirmed'] },
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
        status: { [Op.in]: ['confirmed', 'completed'] },
      },
    });

    // Count today's appointments
    const todayCount = await Appointment.count({
      where: {
        businessId,
        appointmentDate: today,
        status: { [Op.in]: ['confirmed'] },
      },
    });
    const yesterdayCount = await Appointment.count({
      where: {
        businessId,
        appointmentDate: yesterday,
        status: { [Op.in]: ['confirmed'] },
      },
    });

    // Count new clients this week
    const thisWeekClients = await Appointment.count({
      where: {
        businessId,
        appointmentDate: { [Op.gte]: startOfWeek },
        status: { [Op.in]: ['confirmed', 'completed'] },
      },
      distinct: true,
      col: 'customerId',
    });

    const lastWeekClients = await Appointment.count({
      where: {
        businessId,
        appointmentDate: { [Op.between]: [lastWeekStart, lastWeekEnd] },
        status: { [Op.in]: ['confirmed', 'completed'] },
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
        status: { [Op.in]: ['confirmed', 'completed'] },
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
          status: { [Op.in]: ['confirmed'] },
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
      business: {
        id: business.id,
        name: business.businessName,
        businessType: business.businessType,
        approvalStatus: business.approvalStatus,
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

// Get owner's business information
export const getMyBusiness = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ message: 'User not authenticated' });
    }

    // Get business owned by the user
    const business = await Business.findOne({
      where: { ownerId: userId, isActive: true },
    });

    if (!business) {
      return res.status(404).json({ message: 'Business not found' });
    }

    res.json(business);
  } catch (error: any) {
    console.error('Get my business error:', error);
    res.status(500).json({ message: 'Error fetching business', error: error.message });
  }
};

// Get availability data for a business (public route for booking)
export const getBusinessAvailability = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { id } = req.params;
    const { startDate, endDate, staffId: staffIdParam } = req.query;

    let staffIdFilter: number | null = null;
    if (staffIdParam) {
      const parsedStaffId = Number(staffIdParam);
      if (Number.isNaN(parsedStaffId)) {
        return res.status(400).json({ message: 'Invalid staffId parameter' });
      }
      const staffMember = await StaffMember.findOne({
        where: {
          id: parsedStaffId,
          businessId: id,
          isActive: true,
        },
      });
      if (!staffMember) {
        return res.status(404).json({ message: 'Staff member not found for this business' });
      }
      staffIdFilter = staffMember.id;
    }

    const whereClause: any = {
      businessId: id,
      status: { [Op.in]: ['confirmed', 'completed'] },
    };

    if (staffIdFilter) {
      whereClause.staffId = staffIdFilter;
    }

    if (startDate && endDate) {
      whereClause.appointmentDate = {
        [Op.between]: [startDate as string, endDate as string],
      };
    }

    const appointments = await Appointment.findAll({
      where: whereClause,
      attributes: ['appointmentDate', 'startTime', 'endTime'],
    });

    const shiftWhere: any = {
      businessId: id,
    };
    if (staffIdFilter) {
      shiftWhere.staffId = staffIdFilter;
    }
    if (startDate && endDate) {
      shiftWhere.shiftDate = {
        [Op.between]: [startDate as string, endDate as string],
      };
    }

    const shifts = await Shift.findAll({
      where: shiftWhere,
      attributes: ['shiftDate', 'startTime', 'endTime'],
    });

    const bookedDays = Array.from(
      new Set(appointments.map((apt) => apt.appointmentDate.toString()))
    );

    const bookedSlots = appointments.map((apt) => ({
      startAt: `${apt.appointmentDate}T${apt.startTime}`,
      endAt: `${apt.appointmentDate}T${apt.endTime}`,
    }));

    const shiftSlots = shifts.map((shift) => ({
      startAt: `${shift.shiftDate}T${shift.startTime}`,
      endAt: `${shift.shiftDate}T${shift.endTime}`,
    }));

    res.json({
      businessId: id,
      startDate: startDate ?? null,
      endDate: endDate ?? null,
      staffId: staffIdFilter,
      bookedDays,
      bookedSlots,
      shiftSlots,
    });
  } catch (error: any) {
    console.error('Get business availability error:', error);
    res.status(500).json({ message: 'Error fetching availability', error: error.message });
  }
};

// Remove staff member (Business owner only)
export const removeStaffMember = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const userId = req.user?.id;
    const staffId = req.params.staffId || req.params.id;

    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    // Get business owned by the user
    const business = await Business.findOne({
      where: { ownerId: userId, isActive: true },
    });

    if (!business) {
      return res.status(404).json({ message: 'Business not found' });
    }

    // Find staff member
    const staffMember = await StaffMember.findOne({
      where: {
        id: staffId,
        businessId: business.id
      },
      include: [{
        model: User,
        as: 'user',
        attributes: ['id', 'email', 'firstName', 'lastName', 'fullName']
      }]
    });

    if (!staffMember) {
      return res.status(404).json({ message: 'Staff member not found' });
    }

    const activeAppointments = await Appointment.findAll({
      where: {
        staffId: staffMember.id,
        status: {
          [Op.in]: [ AppointmentStatus.CONFIRMED],
        },
      },
      include: [
        {
          model: Business,
          as: 'business',
          attributes: ['id', 'businessName'],
        },
        {
          model: User,
          as: 'customer',
          attributes: ['id', 'email', 'firstName', 'lastName'],
        },
        {
          model: Service,
          as: 'services',
          through: { attributes: [] },
          attributes: ['id', 'name'],
        },
      ],
    });

    const cancelledAppointments: number[] = [];

    for (const appointment of activeAppointments) {
      await appointment.update({ status: AppointmentStatus.CANCELLED });
      cancelledAppointments.push(appointment.id);

      try {
        const appointmentData = appointment.toJSON() as any;
        const appointmentDate =
          appointment.appointmentDate instanceof Date
            ? appointment.appointmentDate.toISOString().split('T')[0]
            : appointment.appointmentDate;
        const appointmentDateTime = `${appointmentDate} at ${appointment.startTime}`;
        const businessName =
          appointmentData.business?.businessName || business.businessName;
        const customerEmail = appointmentData.customer?.email;
        const customerName = appointmentData.customer?.firstName;

        if (customerEmail) {
          const EmailService = (await import('../services/emailService')).default;
          await EmailService.sendAppointmentCancellation({
            email: customerEmail,
            name: customerName,
            businessName,
            appointmentDate,
            startTime:
              appointment.startTime.length === 5
                ? appointment.startTime
                : appointment.startTime.substring(0, 5),
          });
        }

        if (appointmentData.customer?.id) {
          await notificationService.sendNotification({
            userId: appointmentData.customer.id.toString(),
            type: 'appointment_cancelled_by_business',
            title: 'Appointment cancelled',
            message: `Your appointment at ${businessName} on ${appointmentDateTime} was cancelled because your specialist is no longer available.`,
            relatedId: appointment.id.toString(),
            relatedType: 'appointment',
            actionUrl: `/appointments/${appointment.id}`,
          });
        }
      } catch (cancelError) {
        console.error(
          `Failed to notify customer for appointment ${appointment.id} cancellation:`,
          cancelError
        );
      }
    }

    // Save staff data BEFORE deletion
    const staffData = staffMember.toJSON() as any;
    const staffUserId = staffData.user?.id;
    const staffEmail = staffData.user?.email;
    const staffFirstName = staffData.user?.firstName || 'Staff';
    const staffLastName = staffData.user?.lastName || 'Member';
    const staffFullName = staffData.user?.fullName || `${staffFirstName} ${staffLastName}`;

    // Send goodbye EMAIL ONLY to staff (no notification - account will be deleted)
    try {
      const EmailService = (await import('../services/emailService')).default;
      await EmailService.sendEmail({
        to: staffEmail,
        subject: '👋 Thank You for Your Service',
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
            <h2 style="color: #333; border-bottom: 3px solid #007bff; padding-bottom: 10px;">👋 Thank You</h2>
            <p style="color: #555; line-height: 1.6;">Hi ${staffFirstName}! 👋</p>
            <p style="color: #555; line-height: 1.6;">We wanted to let you know that your staff membership at <strong>${business.businessName}</strong> has ended.</p>
            <div style="background-color: white; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #007bff;">
              <p style="margin: 5px 0;"><strong>🏢 Business:</strong> ${business.businessName}</p>
              <p style="margin: 5px 0;"><strong>👤 Your Name:</strong> ${staffFullName}</p>
            </div>
            <p style="color: #555; line-height: 1.6;">Your account has been removed from the platform. Thank you so much for your hard work and dedication! We truly appreciate everything you've contributed. 💙</p>
            <p style="color: #555; line-height: 1.6;">We wish you all the best in your future endeavors! You'll do amazing things! 🌟</p>
            <p style="color: #999; font-size: 12px; margin-top: 30px;">Best wishes for your future! ✨</p>
          </div>
        `
      });
    } catch (emailError) {
      console.error('Failed to send removal email:', emailError);
    }

    // Send notification + email to business owner
    try {
      const owner = await User.findByPk(business.ownerId);
      if (owner) {
        await notificationService.sendNotification({
          userId: business.ownerId.toString(),
          type: 'staff_removed',
          title: '👥 Staff Member Removed',
          message: `${staffFullName} has been removed from your team`,
          relatedId: business.id.toString(),
          relatedType: 'appointment',
          actionUrl: `/business/staff`,
          emailData: {
            to: owner.email,
            subject: '👥 Staff Member Removed',
            html: `
              <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
                <h2 style="color: #333; border-bottom: 3px solid #007bff; padding-bottom: 10px;">👥 Team Update</h2>
                <p style="color: #555; line-height: 1.6;">Hello! 👋</p>
                <p style="color: #555; line-height: 1.6;">A staff member has been removed from your team.</p>
                <div style="background-color: white; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #007bff;">
                  <p style="margin: 5px 0;"><strong>👤 Staff Member:</strong> ${staffFullName}</p>
                  <p style="margin: 5px 0;"><strong>📧 Email:</strong> ${staffEmail}</p>
                  <p style="margin: 5px 0;"><strong>🏢 Business:</strong> ${business.businessName}</p>
                </div>
                <p style="color: #555; line-height: 1.6;">The staff member's account has been removed from the platform. 💙</p>
                <p style="color: #999; font-size: 12px; margin-top: 30px;">Your team roster has been updated. 🌟</p>
              </div>
            `
          }
        });
      }
    } catch (notifError) {
      console.error('Failed to send business owner notification:', notifError);
    }

    // NOW delete staff member record (hard delete) - AFTER emails/notifications sent
    await staffMember.destroy();

    // Delete user account (hard delete)
    await User.destroy({ where: { id: staffUserId } });

    res.json({
      message: 'Staff member and account removed successfully',
      staffMember: {
        id: staffData.id,
        name: staffFullName,
        email: staffEmail
      },
      cancelledAppointments
    });
  } catch (error: any) {
    console.error('Remove staff member error:', error);
    res.status(500).json({ message: 'Error removing staff member', error: error.message });
  }
};


