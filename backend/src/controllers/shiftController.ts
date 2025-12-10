import { Response } from 'express';
import { AuthRequest } from '../middleware/auth';
import { Business, StaffMember, Shift, User } from '../models';
import { Op, QueryTypes } from 'sequelize';

// Get shifts for a business
export const getBusinessShifts = async (req: AuthRequest, res: Response): Promise<Response | void> => {
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

    const { startDate, endDate } = req.query;

    const whereClause: any = {
      businessId: business.id,
    };

    if (startDate && endDate) {
      whereClause.shiftDate = {
        [Op.between]: [startDate as string, endDate as string],
      };
    }

    const shifts = await Shift.findAll({
      where: whereClause,
      include: [
        {
          model: StaffMember,
          as: 'staff',
          include: [
            {
              model: User,
              as: 'user',
              attributes: ['id', 'firstName', 'lastName', 'fullName'],
            },
          ],
        },
      ],
      order: [['shiftDate', 'ASC'], ['startTime', 'ASC']],
    });

    res.json(shifts);
  } catch (error: any) {
    console.error('Get business shifts error:', error);
    res.status(500).json({ message: 'Error fetching shifts', error: error.message });
  }
};

// Get staff members for a business
export const getBusinessStaffMembers = async (req: AuthRequest, res: Response): Promise<Response | void> => {
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

    const staff = await StaffMember.findAll({
      where: {
        businessId: business.id,
        isActive: true,
      },
      include: [
        {
          model: User,
          as: 'user',
          attributes: ['id', 'firstName', 'lastName', 'fullName', 'email'],
        },
      ],
      order: [['createdAt', 'ASC']],
    });

    res.json(staff);
  } catch (error: any) {
    console.error('Get business staff members error:', error);
    res.status(500).json({ message: 'Error fetching staff members', error: error.message });
  }
};

// Create a new shift
export const createShift = async (req: AuthRequest, res: Response): Promise<Response | void> => {
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

    const { staffId, shiftDate, startTime, endTime } = req.body;

    // Validate staff member belongs to this business
    const staffMember = await StaffMember.findOne({
      where: {
        id: staffId,
        businessId: business.id,
        isActive: true,
      },
    });

    if (!staffMember) {
      return res.status(404).json({ message: 'Staff member not found' });
    }

    // Check for overlapping shifts
    const overlappingShift = await Shift.findOne({
      where: {
        staffId,
        shiftDate,
        [Op.or]: [
          {
            startTime: { [Op.lte]: startTime },
            endTime: { [Op.gt]: startTime },
          },
          {
            startTime: { [Op.lt]: endTime },
            endTime: { [Op.gte]: endTime },
          },
          {
            startTime: { [Op.gte]: startTime },
            endTime: { [Op.lte]: endTime },
          },
        ],
      },
    });

    if (overlappingShift) {
      return res.status(400).json({ message: 'This staff member already has a shift during this time' });
    }

    const shift = await Shift.create({
      staffId,
      businessId: business.id,
      shiftDate,
      startTime,
      endTime,
    });

    const createdShift = await Shift.findByPk(shift.id, {
      include: [
        {
          model: StaffMember,
          as: 'staff',
          include: [
            {
              model: User,
              as: 'user',
              attributes: ['id', 'firstName', 'lastName', 'fullName'],
            },
          ],
        },
      ],
    });

    res.status(201).json(createdShift);
  } catch (error: any) {
    console.error('Create shift error:', error);
    res.status(500).json({ message: 'Error creating shift', error: error.message });
  }
};

// Update a shift
export const updateShift = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const userId = req.user?.id;
    const { id } = req.params;

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

    const shift = await Shift.findOne({
      where: {
        id,
        businessId: business.id,
      },
    });

    if (!shift) {
      return res.status(404).json({ message: 'Shift not found' });
    }

    const { staffId, shiftDate, startTime, endTime } = req.body;

    // If staffId is being changed, validate the new staff member
    if (staffId && staffId !== shift.staffId) {
      const staffMember = await StaffMember.findOne({
        where: {
          id: staffId,
          businessId: business.id,
          isActive: true,
        },
      });

      if (!staffMember) {
        return res.status(404).json({ message: 'Staff member not found' });
      }
    }

    // Check for overlapping shifts (excluding current shift)
    const overlappingShift = await Shift.findOne({
      where: {
        id: { [Op.ne]: id },
        staffId: staffId || shift.staffId,
        shiftDate: shiftDate || shift.shiftDate,
        [Op.or]: [
          {
            startTime: { [Op.lte]: startTime || shift.startTime },
            endTime: { [Op.gt]: startTime || shift.startTime },
          },
          {
            startTime: { [Op.lt]: endTime || shift.endTime },
            endTime: { [Op.gte]: endTime || shift.endTime },
          },
          {
            startTime: { [Op.gte]: startTime || shift.startTime },
            endTime: { [Op.lte]: endTime || shift.endTime },
          },
        ],
      },
    });

    if (overlappingShift) {
      return res.status(400).json({ message: 'This staff member already has a shift during this time' });
    }

    await shift.update({
      staffId: staffId || shift.staffId,
      shiftDate: shiftDate || shift.shiftDate,
      startTime: startTime || shift.startTime,
      endTime: endTime || shift.endTime,
    });

    const updatedShift = await Shift.findByPk(shift.id, {
      include: [
        {
          model: StaffMember,
          as: 'staff',
          include: [
            {
              model: User,
              as: 'user',
              attributes: ['id', 'firstName', 'lastName', 'fullName'],
            },
          ],
        },
      ],
    });

    res.json(updatedShift);
  } catch (error: any) {
    console.error('Update shift error:', error);
    res.status(500).json({ message: 'Error updating shift', error: error.message });
  }
};

// Delete a shift
export const deleteShift = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const userId = req.user?.id;
    const { id } = req.params;

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

    const shift = await Shift.findOne({
      where: {
        id,
        businessId: business.id,
      },
    });

    if (!shift) {
      return res.status(404).json({ message: 'Shift not found' });
    }

    await shift.destroy();

    res.json({ message: 'Shift deleted successfully' });
  } catch (error: any) {
    console.error('Delete shift error:', error);
    res.status(500).json({ message: 'Error deleting shift', error: error.message });
  }
};

// Get available time slots for a staff member on a specific date (public route for booking)
export const getAvailableTimeSlots = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { businessId, staffId, date, duration } = req.query;

    console.log('getAvailableTimeSlots called with:', { businessId, staffId, date, duration });

    if (!businessId || !staffId || !date) {
      console.log('Missing required params - returning 400');
      return res.status(400).json({ message: 'businessId, staffId, and date are required' });
    }

    const appointmentDuration = duration ? Number(duration) : 60; // default 60 minutes if not provided

    // Get the shift for this staff member on this date
    const shift = await Shift.findOne({
      where: {
        businessId: Number(businessId),
        staffId: Number(staffId),
        shiftDate: date as string,
      },
    });

    console.log('Found shift:', shift ? `ID ${shift.id}` : 'none');

    if (!shift) {
      return res.json({ availableSlots: [] });
    }

    // Get existing appointments for this staff member on this date
    const appointments = await Business.sequelize!.query(`
      SELECT startTime, endTime 
      FROM appointments 
      WHERE businessId = :businessId 
        AND staffId = :staffId 
        AND appointmentDate = :date 
        AND status IN ('pending', 'confirmed')
      ORDER BY startTime
    `, {
      replacements: { businessId, staffId, date },
      type: QueryTypes.SELECT,
    }) as any[];

    console.log(`Found ${appointments.length} booked appointments`);

    // Parse shift start and end times
    const [shiftStartHour, shiftStartMin] = shift.startTime.split(':').map(Number);
    const [shiftEndHour, shiftEndMin] = shift.endTime.split(':').map(Number);
    
    const shiftStartMinutes = shiftStartHour * 60 + shiftStartMin;
    const shiftEndMinutes = shiftEndHour * 60 + shiftEndMin;
    
    // Convert appointments to minute ranges
    const bookedRanges = appointments.map((apt: any) => {
      const [startHour, startMin] = apt.startTime.split(':').map(Number);
      const [endHour, endMin] = apt.endTime.split(':').map(Number);
      return {
        start: startHour * 60 + startMin,
        end: endHour * 60 + endMin
      };
    });

    // Find available time blocks
    const availableSlots: any[] = [];
    
    // Try each minute from shift start to shift end
    for (let currentMinutes = shiftStartMinutes; currentMinutes + appointmentDuration <= shiftEndMinutes; currentMinutes += 15) {
      const slotEndMinutes = currentMinutes + appointmentDuration;
      
      // Check if this time slot conflicts with any booked appointment
      const hasConflict = bookedRanges.some(range => {
        // Check if proposed slot overlaps with booked range
        return (currentMinutes < range.end && slotEndMinutes > range.start);
      });
      
      if (!hasConflict) {
        const startHour = Math.floor(currentMinutes / 60);
        const startMin = currentMinutes % 60;
        const startTime = `${String(startHour).padStart(2, '0')}:${String(startMin).padStart(2, '0')}:00`;
        
        const endHour = Math.floor(slotEndMinutes / 60);
        const endMin = slotEndMinutes % 60;
        const endTime = `${String(endHour).padStart(2, '0')}:${String(endMin).padStart(2, '0')}:00`;
        
        availableSlots.push({
          startTime,
          endTime,
        });
      }
    }

    console.log(`Returning ${availableSlots.length} available slots for ${appointmentDuration} minute duration`);

    res.json({ availableSlots });
  } catch (error: any) {
    console.error('Get available time slots error:', error);
    res.status(500).json({ message: 'Error fetching available time slots', error: error.message });
  }
};

// Get all shifts for a staff member (public route for booking calendar)
export const getStaffShifts = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { businessId, staffId, startDate, endDate } = req.query;

    console.log('getStaffShifts called with:', { businessId, staffId, startDate, endDate });

    if (!businessId || !staffId) {
      console.log('Missing required params - returning 400');
      return res.status(400).json({ message: 'businessId and staffId are required' });
    }

    const whereClause: any = {
      businessId: Number(businessId),
      staffId: Number(staffId),
    };

    if (startDate && endDate) {
      whereClause.shiftDate = {
        [Op.between]: [startDate as string, endDate as string],
      };
    }

    console.log('Querying shifts with:', whereClause);

    const shifts = await Shift.findAll({
      where: whereClause,
      attributes: ['id', 'shiftDate', 'startTime', 'endTime'],
      order: [['shiftDate', 'ASC']],
    });

    console.log(`Found ${shifts.length} shifts`);

    // Return array of unique dates where staff has shifts
    const availableDates = [...new Set(shifts.map(shift => shift.shiftDate.toString()))];

    console.log('Returning availableDates:', availableDates);

    res.json({
      shifts,
      availableDates,
    });
  } catch (error: any) {
    console.error('Get staff shifts error:', error);
    res.status(500).json({ message: 'Error fetching staff shifts', error: error.message });
  }
};
