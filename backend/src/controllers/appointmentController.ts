import { Response } from 'express';
import { Op } from 'sequelize';
import { AuthRequest } from '../middleware/auth';
import { Appointment, Service, Business, StaffMember, User, AppointmentService } from '../models';
import { AppointmentStatus } from '../models/Appointment';

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
      status: AppointmentStatus.PENDING,
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
          attributes: ['id', 'businessName', 'address', 'city', 'state', 'phone', 'email'],
          include: [
            {
              model: User,
              as: 'owner',
              attributes: ['id', 'fullName', 'firstName', 'email'],
            },
          ],
        },
        {
          model: StaffMember,
          as: 'staff',
          include: [{
            model: User,
            as: 'user',
            attributes: ['fullName', 'firstName', 'lastName', 'email'],
          }],
        },
      ],
    });

    if (!completeAppointment) {
      return res.status(500).json({ message: 'Unable to load appointment details' });
    }

    const customerEmail = (req.user as User)?.email || completeAppointment.customer?.email;
    const dateLabel = new Date(completeAppointment.appointmentDate).toDateString();
    const startLabel = completeAppointment.startTime.substring(0, 5);
    const endLabel = completeAppointment.endTime.substring(0, 5);
    const serviceNames =
      completeAppointment.services?.map((service) => service.name).filter(Boolean) ?? [];
    const businessName = completeAppointment.business?.businessName || 'Rendivo Partner';
    const owner = completeAppointment.business?.owner;
    const ownerEmail = owner?.email || completeAppointment.business?.email;
    const ownerName = owner?.fullName || owner?.firstName;
    const staffUser = completeAppointment.staff?.user;
    const staffName =
      staffUser?.fullName ||
      [staffUser?.firstName, staffUser?.lastName].filter(Boolean).join(' ') ||
      undefined;
    const customerName =
      completeAppointment.customer?.fullName ||
      (req.user as User)?.fullName ||
      customerEmail ||
      'Customer';

    if (customerEmail) {
      try {
        await EmailService.sendAppointmentConfirmation({
          email: customerEmail,
          name: completeAppointment.customer?.fullName || (req.user as User)?.fullName,
          businessName,
          appointmentDate: dateLabel,
          startTime: startLabel,
          endTime: endLabel,
        });
      } catch (emailError) {
        console.error('Failed to send appointment confirmation email:', emailError);
      }
    }

    if (ownerEmail) {
      const ownerTargetEmail = ownerEmail as string;
      try {
        await EmailService.sendBusinessAppointmentCreated({
          email: ownerTargetEmail,
          ownerName,
          businessName,
          customerName,
          appointmentDate: dateLabel,
          startTime: startLabel,
          endTime: endLabel,
          services: serviceNames,
          staffName,
        });
      } catch (ownerEmailError) {
        console.error('Failed to send business appointment email:', ownerEmailError);
      }
    }

    if (staffUser?.email) {
      const staffTargetEmail = staffUser.email as string;
      try {
        await EmailService.sendStaffAppointmentAssigned({
          email: staffTargetEmail,
          staffName,
          businessName,
          customerName,
          appointmentDate: dateLabel,
          startTime: startLabel,
          endTime: endLabel,
          services: serviceNames,
        });
      } catch (staffEmailError) {
        console.error('Failed to send staff appointment email:', staffEmailError);
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
          model: Service,
          as: 'services',
          attributes: ['name'],
          through: { attributes: [] },
        },
        {
          model: Business,
          as: 'business',
          attributes: ['businessName', 'email'],
          include: [
            {
              model: User,
              as: 'owner',
              attributes: ['fullName', 'firstName', 'email'],
            },
          ],
        },
        {
          model: StaffMember,
          as: 'staff',
          include: [{
            model: User,
            as: 'user',
            attributes: ['fullName', 'firstName', 'lastName', 'email'],
          }],
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
          model: Service,
          as: 'services',
          attributes: ['name'],
          through: { attributes: [] },
        },
        {
          model: Business,
          as: 'business',
          attributes: ['businessName', 'email'],
          include: [
            {
              model: User,
              as: 'owner',
              attributes: ['fullName', 'firstName', 'email'],
            },
          ],
        },
        {
          model: StaffMember,
          as: 'staff',
          include: [{
            model: User,
            as: 'user',
            attributes: ['fullName', 'firstName', 'lastName', 'email'],
          }],
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
    const customerName = appointment.customer?.fullName || 'Customer';
    const owner = appointment.business?.owner;
    const ownerEmail = owner?.email || appointment.business?.email;
    const ownerName = owner?.fullName || owner?.firstName;
    const staffUser = appointment.staff?.user;
    const staffEmail = staffUser?.email;
    const staffName =
      staffUser?.fullName ||
      [staffUser?.firstName, staffUser?.lastName].filter(Boolean).join(' ') ||
      undefined;
    const serviceNames =
      appointment.services?.map((service) => service.name).filter(Boolean) ?? [];
    const dateLabel = new Date(appointmentDate).toDateString();
    const startLabel = startTime.substring(0, 5);

    await appointment.destroy();

    if (customerEmail) {
      try {
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

    if (ownerEmail) {
      const ownerTargetEmail = ownerEmail as string;
      try {
        await EmailService.sendBusinessAppointmentCancelled({
          email: ownerTargetEmail,
          ownerName,
          businessName,
          customerName,
          appointmentDate: dateLabel,
          startTime: startLabel,
          services: serviceNames,
          staffName,
        });
      } catch (businessEmailError) {
        console.error('Failed to send business cancellation email:', businessEmailError);
      }
    }

    if (staffEmail) {
      const staffTargetEmail = staffEmail as string;
      try {
        await EmailService.sendStaffAppointmentCancelled({
          email: staffTargetEmail,
          staffName,
          businessName,
          customerName,
          appointmentDate: dateLabel,
          startTime: startLabel,
          services: serviceNames,
        });
      } catch (staffEmailError) {
        console.error('Failed to send staff cancellation email:', staffEmailError);
      }
    }

    res.json({
      message: 'Appointment cancelled successfully',
    });
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

// Public: Get booked days and slots for a business within a date range
export const getBusinessAvailability = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { businessId } = req.params;
    const { startDate, endDate } = req.query;

    if (!businessId) {
      return res.status(400).json({ message: 'businessId is required' });
    }

    const business = await Business.findByPk(businessId);
    if (!business) {
      return res.status(404).json({ message: 'Business not found' });
    }

    const today = new Date();
    const start = startDate ? new Date(startDate as string) : today;
    const end = endDate
      ? new Date(endDate as string)
      : new Date(today.getFullYear(), today.getMonth(), today.getDate() + 31);

    const appointments = await Appointment.findAll({
      where: {
        businessId: business.id,
        status: { [Op.ne]: AppointmentStatus.CANCELLED },
        appointmentDate: {
          [Op.gte]: start,
          [Op.lte]: end,
        },
      },
      attributes: ['id', 'appointmentDate', 'startTime', 'endTime', 'staffId', 'status'],
      order: [['appointmentDate', 'ASC'], ['startTime', 'ASC']],
    });

    const bookedDays = new Set<string>();
    const bookedSlots = appointments.map((appt) => {
      const dateStr = appt.appointmentDate
        ? new Date(appt.appointmentDate).toISOString().split('T')[0]
        : '';
      if (dateStr) bookedDays.add(dateStr);
      const startAt = `${dateStr}T${appt.startTime}`;
      const endAt = `${dateStr}T${appt.endTime}`;
      return {
        appointmentId: appt.id,
        date: dateStr,
        start: appt.startTime,
        end: appt.endTime,
        startAt,
        endAt,
        staffId: appt.staffId,
        status: appt.status,
      };
    });

    res.json({
      businessId: business.id,
      startDate: start.toISOString().split('T')[0],
      endDate: end.toISOString().split('T')[0],
      bookedDays: Array.from(bookedDays),
      bookedSlots,
    });
  } catch (error: any) {
    console.error('Get business availability error:', error);
    res.status(500).json({ message: 'Error fetching availability', error: error.message });
  }
};
