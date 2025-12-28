import { Op } from 'sequelize';
import firebaseAdmin from '../config/firebase';
import { UserDeviceToken } from '../models';

type PushPayload = {
  title: string;
  body: string;
  data?: Record<string, string>;
};

const INVALID_TOKEN_ERRORS = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

const resolveTokensForUsers = async (userIds: number[]) => {
  if (!userIds.length) return [];
  const tokens = await UserDeviceToken.findAll({
    where: {
      userId: {
        [Op.in]: userIds,
      },
    },
    attributes: ['token'],
  });
  return tokens.map((token) => token.token);
};

const sendToTokens = async (tokens: string[], payload: PushPayload) => {
  if (!firebaseAdmin) {
    console.warn('Push notifications skipped: Firebase Admin not configured');
    return;
  }

  if (!tokens.length) return;

  const response = await firebaseAdmin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: payload.data,
  });

  const invalidTokens: string[] = [];
  response.responses.forEach((result, index) => {
    if (!result.success) {
      const code = result.error?.code;
      if (code && INVALID_TOKEN_ERRORS.has(code)) {
        invalidTokens.push(tokens[index]);
      }
      console.warn('Push send failed:', result.error?.message || code);
    }
  });

  if (invalidTokens.length) {
    await UserDeviceToken.destroy({
      where: {
        token: {
          [Op.in]: invalidTokens,
        },
      },
    });
  }
};

export const sendPushToUsers = async (userIds: number[], payload: PushPayload) => {
  const uniqueUserIds = Array.from(new Set(userIds.filter((id) => Number.isFinite(id))));
  if (!uniqueUserIds.length) return;
  const tokens = await resolveTokensForUsers(uniqueUserIds);
  await sendToTokens(tokens, payload);
};
