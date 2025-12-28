import { Response } from 'express';
import { DeviceToken } from '../models';
import { AuthRequest } from '../middleware/auth';

export const registerDeviceToken = async (
  req: AuthRequest,
  res: Response
): Promise<Response> => {
  try {
    const user = req.user;
    const { token, platform } = req.body || {};

    if (!user) {
      return res.status(401).json({ message: 'Not authenticated' });
    }

    if (!token || typeof token !== 'string') {
      return res.status(400).json({ message: 'Token is required' });
    }

    const normalizedPlatform =
      typeof platform === 'string' && platform.trim()
        ? platform.trim()
        : 'android';

    const existing = await DeviceToken.findOne({ where: { token } });

    if (existing) {
      if (existing.userId !== user.id || existing.platform !== normalizedPlatform) {
        existing.userId = user.id;
        existing.platform = normalizedPlatform;
        await existing.save();
      }
    } else {
      await DeviceToken.create({
        userId: user.id,
        token,
        platform: normalizedPlatform,
      });
    }

    return res.status(200).json({ message: 'Device token saved' });
  } catch (error) {
    console.error('Device token registration error:', error);
    return res.status(500).json({ message: 'Failed to save device token' });
  }
};

export const deleteDeviceToken = async (
  req: AuthRequest,
  res: Response
): Promise<Response> => {
  try {
    const user = req.user;
    const { token } = req.body || {};

    if (!user) {
      return res.status(401).json({ message: 'Not authenticated' });
    }

    if (!token || typeof token !== 'string') {
      return res.status(400).json({ message: 'Token is required' });
    }

    await DeviceToken.destroy({
      where: {
        userId: user.id,
        token,
      },
    });

    return res.status(200).json({ message: 'Device token removed' });
  } catch (error) {
    console.error('Device token removal error:', error);
    return res.status(500).json({ message: 'Failed to remove device token' });
  }
};
