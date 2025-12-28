import { Router, Response } from 'express';
import { AuthRequest, authenticate } from '../middleware/auth';
import { notificationService } from '../services/notificationService';

const router = Router();

/**
 * POST /api/notifications/register-token
 * Register FCM token for push notifications
 */
router.post('/register-token', authenticate, async (req: AuthRequest, res: Response): Promise<Response | void> => {
  try {
    const { fcmToken } = req.body;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    if (!fcmToken) {
      return res.status(400).json({ message: 'FCM token is required' });
    }

    await notificationService.saveFCMToken(userId.toString(), fcmToken);

    return res.json({ message: 'FCM token registered successfully' });
  } catch (error: any) {
    console.error('Error registering FCM token:', error);
    return res.status(500).json({ message: 'Error registering FCM token', error: error.message });
  }
});

export default router;
