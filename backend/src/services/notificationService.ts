import { Op } from 'sequelize';
import { DeviceToken } from '../models';
import firebaseAdmin from '../config/firebase';

export interface NotificationPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

class NotificationService {
  async sendToUsers(userIds: number[], payload: NotificationPayload): Promise<void> {
    if (!firebaseAdmin) {
      console.warn('Firebase admin not configured. Skipping push notification.');
      return;
    }
    if (!userIds.length) return;

    const tokens = await DeviceToken.findAll({
      where: { userId: { [Op.in]: userIds } },
      attributes: ['token'],
    });

    const tokenList = tokens.map((token) => token.token).filter(Boolean);
    if (!tokenList.length) return;

    const response = await firebaseAdmin.messaging().sendEachForMulticast({
      tokens: tokenList,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      android: {
        notification: {
          channelId: 'rendivo_notifications',
        },
      },
      data: payload.data ?? {},
    });

    console.log(
      `Push sent. Success: ${response.successCount}, Failure: ${response.failureCount}`
    );

    const invalidTokens: string[] = [];
    response.responses.forEach((res, index) => {
      if (!res.success) {
        console.error('Push error:', res.error);
        const code = res.error?.code ?? '';
        if (code.includes('registration-token-not-registered')) {
          invalidTokens.push(tokenList[index]);
        }
      }
    });

    if (invalidTokens.length) {
      await DeviceToken.destroy({ where: { token: { [Op.in]: invalidTokens } } });
    }
  }
}

export default new NotificationService();
