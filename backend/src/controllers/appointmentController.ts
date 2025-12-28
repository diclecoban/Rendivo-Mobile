import { Response } from 'express';
import { Op } from 'sequelize';
import { AuthRequest } from '../middleware/auth';
import { Appointment, Service, Business, StaffMember, User, AppointmentService } from '../models';
import { AppointmentStatus } from '../models/Appointment';
import EmailService from '../services/emailService';
import notificationService from '../services/notificationService';

const formatDateLabel = (date: Date | string) =>
  new Date(date).toDateString();

const formatTimeLabel = (time: string) => time.substring(0, 5);

// Create a new appointment
export const createAppointment = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { businessId, staffId, serviceIds, appointmentDate, startTime, notes } = req.body;
    const customerId = req.user?.id;

    if (!customerId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    // Validate required fields
    if (!businessId || !staffId || !serviceIds || !appointmentDate || !startTime) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    // Fetch services to calculate total price and duration
    const services = await Service.findAll({
      where: {
        id: serviceIds,
        businessId,
        isActive: true,
      },
    });

    if (services.length !== serviceIds.length) {
      return res.status(400).json({ message: 'Some services not found or inactive' });
    }

    const totalPrice = services.reduce((sum, service) => sum + Number(service.price), 0);
    const totalDuration = services.reduce((sum, service) => sum + service.duration, 0);

    // Calculate end time
    const [hours, minutes] = startTime.split(':').map(Number);
    const endMinutes = hours * 60 + minutes + totalDuration;
    const endHours = Math.floor(endMinutes / 60);
    const endMins = endMinutes % 60;
    const endTime = `${String(endHours).padStart(2, '0')}:${String(endMins).padStart(2, '0')}:00`;

    // Create appointment
    const appointment = await Appointment.create({
      customerId,
      businessId,
      staffId,
      appointmentDate,
      startTime,
      endTime,
      totalPrice,
      totalDuration,
      status: AppointmentStatus.CONFIRMED,
      notes,
    });

    // Create appointment-service relationships
    await Promise.all(
      serviceIds.map((serviceId: number) =>
        AppointmentService.create({
          appointmentId: appointment.id,
          serviceId,
        })
      )
    );

    // Fetch complete appointment with associations
    const completeAppointment = await Appointment.findByPk(appointment.id, {
      include: [
        {
          model: Service,
          as: 'services',
          through: { attributes: [] },
        },
        {
          model: Business,
          as: 'business',
          attributes: ['id', 'businessName', 'address', 'city', 'state', 'phone', 'ownerId'],
        },
        {
          model: StaffMember,
          as: 'staff',
          include: [{
            model: User,
            as: 'user',
            attributes: ['id', 'fullName'],
          }],
        },
        {
          model: User,
          as: 'customer',
          attributes: ['id', 'fullName', 'email'],
        },
      ],
    });

    const customerEmail = (req.user as User)?.email || completeAppointment?.customer?.email;
    if (customerEmail && completeAppointment) {
      const dateLabel = new Date(completeAppointment.appointmentDate).toDateString();
      const startLabel = completeAppointment.startTime.substring(0, 5);
      const endLabel = completeAppointment.endTime.substring(0, 5);
      try {
        await EmailService.sendAppointmentConfirmation({
          email: customerEmail,
          name: completeAppointment.customer?.fullName || (req.user as User)?.fullName,
          businessName: completeAppointment.business?.businessName || 'Rendivo Partner',
          appointmentDate: dateLabel,
          startTime: startLabel,
          endTime: endLabel,
        });
      } catch (emailError) {
        console.error('Failed to send appointment confirmation email:', emailError);
      }
    }

    if (completeAppointment) {
      const appointmentDate = formatDateLabel(completeAppointment.appointmentDate);
      const startLabel = formatTimeLabel(completeAppointment.startTime);
      const businessName = completeAppointment.business?.businessName || 'Rendivo Partner';
      const businessOwnerId = completeAppointment.business?.ownerId;
      const staffUserId = (completeAppointment.staff as any)?.user?.id;

      await notificationService.sendToUsers(
        [completeAppointment.customerId],
        {
          title: 'Randevunuz onaylandı',
          body: `${businessName} randevunuz ${appointmentDate} ${startLabel} için onaylandı.`,
          data: {
            type: 'customer_booking',
            appointmentId: String(completeAppointment.id),
          },
        }
      );

      if (businessOwnerId) {
        await notificationService.sendToUsers(
          [businessOwnerId],
          {
            title: 'Yeni randevu',
            body: `${appointmentDate} ${startLabel} için yeni randevu alındı.`,
            data: {
              type: 'business_new_appointment',
              appointmentId: String(completeAppointment.id),
            },
          }
        );
      }

      if (staffUserId) {
        await notificationService.sendToUsers(
          [staffUserId],
          {
            title: 'Yeni randevu',
            body: `${appointmentDate} ${startLabel} için randevu atandı.`,
            data: {
              type: 'staff_new_appointment',
              appointmentId: String(completeAppointment.id),
            },
          }
        );
      }
    }

    res.status(201).json({
      message: 'Appointment created successfully',
      appointment: completeAppointment,
    });
  } catch (error: any) {
    console.error('Create appointment error:', error);
    res.status(500).json({ message: 'Error creating appointment', error: error.message });
  }
};

// Get customer's appointments
export const getCustomerAppointments = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const customerId = req.user?.id;

    if (!customerId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const appointments = await Appointment.findAll({
      where: { customerId },
      include: [
        {
          model: Service,
          as: 'services',
          through: { attributes: [] },
        },
        {
          model: Business,
          as: 'business',
          attributes: ['id', 'businessName', 'address', 'city', 'state', 'phone', 'email'],
        },
        {
          model: StaffMember,
          as: 'staff',
          include: [{
            model: User,
            as: 'user',
            attributes: ['fullName'],
          }],
          attributes: ['id', 'position'],
        },
      ],
      order: [['appointmentDate', 'DESC'], ['startTime', 'DESC']],
    });

    res.json(appointments);
  } catch (error: any) {
    console.error('Get customer appointments error:', error);
    res.status(500).json({ message: 'Error fetching appointments', error: error.message });
  }
};

// Get business appointments (Business owner only)
export const getBusinessAppointments = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    // Find business owned by this user
    const business = await Business.findOne({ where: { ownerId: userId } });
    if (!business) {
      return res.status(404).json({ message: 'Business not found' });
    }

    const appointments = await Appointment.findAll({
      where: { businessId: business.id },
      include: [
        {
          model: Service,
          as: 'services',
          through: { attributes: [] },
        },
        {
          model: User,
          as: 'customer',
          attributes: ['id', 'fullName', 'email', 'phone'],
        },
        {
          model: StaffMember,
          as: 'staff',
          include: [{
            model: User,
            as: 'user',
            attributes: ['fullName'],
          }],
          attributes: ['id', 'position'],
        },
      ],
      order: [['appointmentDate', 'DESC'], ['startTime', 'DESC']],
    });

    res.json(appointments);
  } catch (error: any) {
    console.error('Get business appointments error:', error);
    res.status(500).json({ message: 'Error fetching appointments', error: error.message });
  }
};

// Get staff appointments (Staff member only)
export const getStaffAppointments = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    // Find staff member record for this user
    const staffMember = await StaffMember.findOne({ where: { userId } });
    if (!staffMember) {
      return res.status(404).json({ message: 'Staff member record not found' });
    }

    const appointments = await Appointment.findAll({
      where: { staffId: staffMember.id },
      include: [
        {
          model: Service,
          as: 'services',
          through: { attributes: [] },
        },
        {
          model: Business,
          as: 'business',
          attributes: ['id', 'businessName', 'address', 'city', 'state', 'phone', 'email'],
        },
        {
          model: User,
          as: 'customer',
          attributes: ['id', 'fullName', 'email', 'phone'],
        },
      ],
      order: [['appointmentDate', 'ASC'], ['startTime', 'ASC']],
    });

    res.json(appointments);
  } catch (error: any) {
    console.error('Get staff appointments error:', error);
    res.status(500).json({ message: 'Error fetching appointments', error: error.message });
  }
};

// Get appointment by ID
export const getAppointmentById = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { id } = req.params;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const appointment = await Appointment.findByPk(id, {
      include: [
        {
          model: Service,
          as: 'services',
          through: { attributes: [] },
        },
        {
          model: Business,
          as: 'business',
          attributes: ['id', 'businessName', 'address', 'city', 'state', 'phone', 'email'],
        },
        {
          model: StaffMember,
          as: 'staff',
          include: [{
            model: User,
            as: 'user',
            attributes: ['fullName'],
          }],
          attributes: ['id', 'position'],
        },
        {
          model: User,
          as: 'customer',
          attributes: ['id', 'fullName', 'email', 'phone'],
        },
      ],
    });

    if (!appointment) {
      return res.status(404).json({ message: 'Appointment not found' });
    }

    // Check authorization: customer or business owner
    const business = await Business.findOne({ where: { ownerId: userId } });
    const isCustomer = appointment.customerId === userId;
    const isBusinessOwner = business && business.id === appointment.businessId;

    if (!isCustomer && !isBusinessOwner) {
      return res.status(403).json({ message: 'Forbidden' });
    }

    res.json(appointment);
  } catch (error: any) {
    console.error('Get appointment error:', error);
    res.status(500).json({ message: 'Error fetching appointment', error: error.message });
  }
};

// Update appointment status (Business owner only)
export const updateAppointmentStatus = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const appointment = await Appointment.findByPk(id, {
      include: [
        {
          model: Business,
          as: 'business',
          attributes: ['businessName'],
        },
        {
          model: User,
          as: 'customer',
          attributes: ['email', 'fullName'],
        },
      ],
    });
    if (!appointment) {
      return res.status(404).json({ message: 'Appointment not found' });
    }

    // Check if user owns the business
    const business = await Business.findOne({ where: { ownerId: userId } });
    if (!business || business.id !== appointment.businessId) {
      return res.status(403).json({ message: 'Forbidden' });
    }

    await appointment.update({ status });

    res.json({
      message: 'Appointment status updated successfully',
      appointment,
    });
  } catch (error: any) {
    console.error('Update appointment status error:', error);
    res.status(500).json({ message: 'Error updating appointment', error: error.message });
  }
};

// Cancel appointment (Customer or Business owner)
export const cancelAppointment = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { id } = req.params;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const appointment = await Appointment.findByPk(id, {
      include: [
        {
          model: Business,
          as: 'business',
          attributes: ['id', 'businessName', 'ownerId'],
        },
        {
          model: StaffMember,
          as: 'staff',
          include: [{
            model: User,
            as: 'user',
            attributes: ['id', 'fullName'],
          }],
        },
        {
          model: User,
          as: 'customer',
          attributes: ['id', 'fullName', 'email'],
        },
      ],
    });
    if (!appointment) {
      return res.status(404).json({ message: 'Appointment not found' });
    }

    // Check authorization
    const business = await Business.findOne({ where: { ownerId: userId } });
    const isCustomer = appointment.customerId === userId;
    const isBusinessOwner = business && business.id === appointment.businessId;

    if (!isCustomer && !isBusinessOwner) {
      return res.status(403).json({ message: 'Forbidden' });
    }

    const appointmentDate = appointment.appointmentDate;
    const startTime = appointment.startTime;
    const businessName = appointment.business?.businessName || 'Rendivo Partner';
    const customerEmail = appointment.customer?.email;
    const customerName = appointment.customer?.fullName;
    const businessOwnerId = appointment.business?.ownerId;
    const staffUserId = (appointment.staff as any)?.user?.id;
    const isBusinessCancel = req.user?.role === 'business_owner';

    await appointment.destroy();

    if (customerEmail) {
      try {
        const dateLabel = formatDateLabel(appointmentDate);
        const startLabel = formatTimeLabel(startTime);
        await EmailService.sendAppointmentCancellation({
          email: customerEmail,
          name: customerName,
          businessName,
          appointmentDate: dateLabel,
          startTime: startLabel,
        });
      } catch (emailError) {
        console.error('Failed to send cancellation email:', emailError);
      }
    }

    res.json({
      message: 'Appointment cancelled successfully',
    });

    const dateLabel = formatDateLabel(appointmentDate);
    const startLabel = formatTimeLabel(startTime);

    if (appointment.customerId) {
      await notificationService.sendToUsers(
        [appointment.customerId],
        {
          title: 'Randevunuz iptal edildi',
          body: isBusinessCancel
            ? `${businessName} randevunuzu iptal etti. (${dateLabel} ${startLabel})`
            : `Randevunuz iptal edildi. (${dateLabel} ${startLabel})`,
          data: {
            type: isBusinessCancel
                ? 'customer_cancellation_by_business'
                : 'customer_cancellation_by_customer',
            appointmentId: String(appointment.id),
          },
        }
      );
    }

    if (businessOwnerId) {
      await notificationService.sendToUsers(
        [businessOwnerId],
        {
          title: 'Randevu iptal edildi',
          body: isBusinessCancel
            ? `${dateLabel} ${startLabel} randevusunu iptal ettiniz.`
            : `Müşteri ${dateLabel} ${startLabel} randevusunu iptal etti.`,
          data: {
            type: isBusinessCancel
                ? 'business_cancellation_by_business'
                : 'business_cancellation_by_customer',
            appointmentId: String(appointment.id),
          },
        }
      );
    }

    if (staffUserId) {
      await notificationService.sendToUsers(
        [staffUserId],
        {
          title: 'Randevu iptal edildi',
          body: `${dateLabel} ${startLabel} randevusu iptal edildi.`,
          data: {
            type: 'staff_appointment_cancelled',
            appointmentId: String(appointment.id),
          },
        }
      );
    }
  } catch (error: any) {
    console.error('Cancel appointment error:', error);
    res.status(500).json({ message: 'Error cancelling appointment', error: error.message });
  }
};

// Reschedule appointment (customer or business owner)
export const rescheduleAppointment = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { id } = req.params;
    const { appointmentDate, startTime, endTime, staffId, serviceIds, totalDuration, totalPrice } = req.body;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    if (!appointmentDate || !startTime || !endTime) {
      return res.status(400).json({ message: 'Appointment date, start time, and end time are required' });
    }

    const appointment = await Appointment.findByPk(id);
    if (!appointment) {
      return res.status(404).json({ message: 'Appointment not found' });
    }

    // Check authorization
    const business = await Business.findOne({ where: { ownerId: userId } });
    const isCustomer = appointment.customerId === userId;
    const isBusinessOwner = business && business.id === appointment.businessId;

    if (!isCustomer && !isBusinessOwner) {
      return res.status(403).json({ message: 'Forbidden' });
    }

    const newStaffId = staffId || appointment.staffId;

    // Check if new time slot is available
    const conflictingAppointment = await Appointment.findOne({
      where: {
        staffId: newStaffId,
        appointmentDate,
        status: {
          [Op.ne]: AppointmentStatus.CANCELLED
        },
        id: {
          [Op.ne]: id
        }
      }
    });

    if (conflictingAppointment) {
      // Check for time overlap
      const newStart = startTime;
      const newEnd = endTime;
      const existingStart = conflictingAppointment.startTime;
      const existingEnd = conflictingAppointment.endTime;

      if (
        (newStart >= existingStart && newStart < existingEnd) ||
        (newEnd > existingStart && newEnd <= existingEnd) ||
        (newStart <= existingStart && newEnd >= existingEnd)
      ) {
        return res.status(409).json({ message: 'This time slot is not available' });
      }
    }

    // Update appointment
    const updateData: any = {
      appointmentDate,
      startTime,
      endTime
    };

    if (staffId) updateData.staffId = staffId;
    if (totalDuration) updateData.totalDuration = totalDuration;
    if (totalPrice) updateData.totalPrice = totalPrice;

    await appointment.update(updateData);

    // Update services if provided
    if (serviceIds && serviceIds.length > 0) {
      // Remove old service associations
      await AppointmentService.destroy({ where: { appointmentId: id } });
      
      // Add new service associations
      for (const serviceId of serviceIds) {
        await AppointmentService.create({
          appointmentId: Number(id),
          serviceId
        });
      }
    }

    const updatedAppointment = await Appointment.findByPk(id, {
      include: [
        {
          model: Service,
          as: 'services',
          through: { attributes: [] },
        },
        {
          model: Business,
          as: 'business',
          attributes: ['id', 'businessName', 'address', 'city', 'state', 'phone', 'email'],
        },
        {
          model: StaffMember,
          as: 'staff',
          include: [{
            model: User,
            as: 'user',
            attributes: ['fullName'],
          }],
          attributes: ['id', 'position'],
        },
      ],
    });

    res.json({
      message: 'Appointment rescheduled successfully',
      appointment: updatedAppointment,
    });
  } catch (error: any) {
    console.error('Reschedule appointment error:', error);
    res.status(500).json({ message: 'Error rescheduling appointment', error: error.message });
  }
};
