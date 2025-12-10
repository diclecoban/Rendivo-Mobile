import { Response } from 'express';
import { AuthRequest } from '../middleware/auth';
import { Service, Business } from '../models';

// Get all services for a business
export const getBusinessServices = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { businessId } = req.params;

    const services = await Service.findAll({
      where: { 
        businessId,
        isActive: true 
      },
      order: [['name', 'ASC']],
    });

    res.json(services);
  } catch (error: any) {
    console.error('Get business services error:', error);
    res.status(500).json({ message: 'Error fetching services', error: error.message });
  }
};

// Get services for logged-in business owner
export const getOwnerServices = async (req: AuthRequest, res: Response): Promise<Response | void> => {
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

    const services = await Service.findAll({
      where: { 
        businessId: business.id,
      },
      order: [['name', 'ASC']],
    });

    res.json(services);
  } catch (error: any) {
    console.error('Get owner services error:', error);
    res.status(500).json({ message: 'Error fetching services', error: error.message });
  }
};

// Create a new service (Business owner only)
export const createService = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { name, description, price, duration } = req.body;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    // Find business owned by this user
    const business = await Business.findOne({ where: { ownerId: userId } });
    if (!business) {
      return res.status(404).json({ message: 'Business not found' });
    }

    const service = await Service.create({
      businessId: business.id,
      name,
      description,
      price,
      duration,
      isActive: true,
    });

    res.status(201).json({
      message: 'Service created successfully',
      service,
    });
  } catch (error: any) {
    console.error('Create service error:', error);
    res.status(500).json({ message: 'Error creating service', error: error.message });
  }
};

// Update a service (Business owner only)
export const updateService = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { id } = req.params;
    const { name, description, price, duration, isActive } = req.body;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const service = await Service.findByPk(id, {
      include: [{
        model: Business,
        as: 'business',
      }],
    });

    if (!service) {
      return res.status(404).json({ message: 'Service not found' });
    }

    // Check if user owns the business
    const business = await Business.findOne({ where: { ownerId: userId } });
    if (!business || business.id !== service.businessId) {
      return res.status(403).json({ message: 'Forbidden: You do not own this business' });
    }

    await service.update({
      name,
      description,
      price,
      duration,
      isActive,
    });

    res.json({
      message: 'Service updated successfully',
      service,
    });
  } catch (error: any) {
    console.error('Update service error:', error);
    res.status(500).json({ message: 'Error updating service', error: error.message });
  }
};

// Delete a service (Business owner only)
export const deleteService = async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { id } = req.params;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const service = await Service.findByPk(id);
    if (!service) {
      return res.status(404).json({ message: 'Service not found' });
    }

    // Check if user owns the business
    const business = await Business.findOne({ where: { ownerId: userId } });
    if (!business || business.id !== service.businessId) {
      return res.status(403).json({ message: 'Forbidden: You do not own this business' });
    }

    await service.destroy();

    res.json({ message: 'Service deleted successfully' });
  } catch (error: any) {
    console.error('Delete service error:', error);
    res.status(500).json({ message: 'Error deleting service', error: error.message });
  }
};
