import { Response } from 'express';
import { AuthRequest } from '../middleware/auth';
import { UserDeviceToken } from '../models';
import { notificationService } from '../services/notificationService';

export const registerDeviceToken = async (
  req: AuthRequest,
  res: Response
): Promise<Response | void> => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const { token, platform } = req.body;
    if (!token) {
      return res.status(400).json({ message: 'Device token is required' });
    }

    const [deviceToken, created] = await UserDeviceToken.findOrCreate({
      where: { token },
      defaults: {
        userId,
        token,
        platform: platform || 'android',
        lastSeenAt: new Date(),
      },
    });

    if (!created) {
      await deviceToken.update({
        userId,
        platform: platform || deviceToken.platform || 'android',
        lastSeenAt: new Date(),
      });
    }

    await notificationService.saveFCMToken(userId.toString(), token);

    res.json({ message: 'Device token registered' });
  } catch (error: any) {
    console.error('Register device token error:', error);
    res.status(500).json({ message: 'Error registering device token', error: error.message });
  }
};

export const deleteDeviceToken = async (
  req: AuthRequest,
  res: Response
): Promise<Response | void> => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const { token } = req.body;
    if (!token) {
      return res.status(400).json({ message: 'Device token is required' });
    }

    await UserDeviceToken.destroy({
      where: {
        userId,
        token,
      },
    });

    res.json({ message: 'Device token removed' });
  } catch (error: any) {
    console.error('Delete device token error:', error);
    res.status(500).json({ message: 'Error deleting device token', error: error.message });
  }
};
