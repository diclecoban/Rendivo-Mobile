import { firebaseAdmin } from '../config/firebase';
import  EmailService  from './emailService';

export interface NotificationData {
  userId: string;
  type: 'appointment_booked' | 'appointment_cancelled_by_customer' | 'appointment_cancelled_by_business' | 
        'appointment_reminder_week' | 'appointment_reminder_day' | 'appointment_reminder_hour' | 'staff_added' | 'staff_removed' |
        'appointment_assigned' | 'appointment_assigned_cancelled' | 'appointment_rescheduled' | 'business_approved' | 'business_rejected';
  title: string;
  message: string;
  relatedId?: string;
  relatedType?: 'appointment' | 'staff' | 'business';
  actionUrl?: string;
  emailData?: {
    to: string;
    subject: string;
    html: string;
  };
}

class NotificationService {
  /**
   * Send notification via Firestore, FCM push, and email
   */
  async sendNotification(data: NotificationData): Promise<void> {
    try {
      console.log('📤 Sending notification:', {
        userId: data.userId,
        type: data.type,
        title: data.title
      });

      // 1. Store in Firestore
      await this.createFirestoreNotification(data);

      // 2. Send push notification if user has FCM token
      await this.sendPushNotification(data);

      // 3. Send email if email data provided
      if (data.emailData) {
        await EmailService.sendEmail(data.emailData);
      }

      console.log('✅ Notification sent successfully');
    } catch (error) {
      console.error('❌ Error sending notification:', error);
      throw error;
    }
  }

  /**
   * Create notification document in Firestore
   */
  private async createFirestoreNotification(data: NotificationData): Promise<void> {
    if (!firebaseAdmin) {
      console.warn('Firebase Admin not initialized - skipping Firestore notification');
      return;
    }

    try {
      const db = firebaseAdmin.firestore();
      const notificationRef = db
        .collection('notifications')
        .doc(data.userId)
        .collection('items')
        .doc();

      await notificationRef.set({
        type: data.type,
        title: data.title,
        message: data.message,
        read: false,
        createdAt: firebaseAdmin.firestore.FieldValue.serverTimestamp(),
        relatedId: data.relatedId || null,
        relatedType: data.relatedType || null,
        actionUrl: data.actionUrl || null,
      });

      console.log(`✅ Firestore notification created for user ${data.userId}`);
    } catch (error) {
      console.error('Error creating Firestore notification:', error);
      throw error;
    }
  }

  /**
   * Send FCM push notification to user's devices
   */
  private async sendPushNotification(data: NotificationData): Promise<void> {
    if (!firebaseAdmin) {
      console.warn('Firebase Admin not initialized - skipping push notification');
      return;
    }

    try {
      // Get user's FCM tokens from Firestore
      const db = firebaseAdmin.firestore();
      const userDoc = await db.collection('users').doc(data.userId).get();
      
      if (!userDoc.exists) {
        console.log(`User ${data.userId} not found in Firestore - skipping push`);
        return;
      }

      const fcmTokens = userDoc.data()?.fcmTokens || [];
      
      if (fcmTokens.length === 0) {
        console.log(`No FCM tokens for user ${data.userId} - skipping push`);
        return;
      }

      // Send to all user's devices
      const messaging = firebaseAdmin.messaging();
      const message = {
        notification: {
          title: data.title,
          body: data.message,
        },
        data: {
          type: data.type,
          notificationId: Date.now().toString(),
          actionUrl: data.actionUrl || '/',
          relatedId: data.relatedId || '',
        },
      };

      // Send to each token individually
      const sendPromises = fcmTokens.map((token: string) =>
        messaging.send({ ...message, token }).catch((error: any) => {
          console.error(`Failed to send to token ${token}:`, error);
          return { success: false, token };
        })
      );

      const results = await Promise.all(sendPromises);
      const successCount = results.filter((r: any) => r !== null && r.success !== false).length;
      const failureCount = results.length - successCount;
      
      console.log(`✅ Push notification sent: ${successCount} success, ${failureCount} failed`);

      // Remove invalid tokens
      if (failureCount > 0) {
        const tokensToRemove = results
          .filter((r: any) => r && r.success === false)
          .map((r: any) => r.token);
        
        if (tokensToRemove.length > 0) {
          await this.removeInvalidTokens(data.userId, tokensToRemove);
        }
      }
    } catch (error) {
      console.error('Error sending push notification:', error);
      // Don't throw - push notification failure shouldn't stop other notifications
    }
  }

  /**
   * Remove invalid FCM tokens from Firestore
   */
  private async removeInvalidTokens(userId: string, tokens: string[]): Promise<void> {
    if (!firebaseAdmin) return;

    try {
      const db = firebaseAdmin.firestore();
      const userRef = db.collection('users').doc(userId);
      
      await userRef.update({
        fcmTokens: firebaseAdmin.firestore.FieldValue.arrayRemove(...tokens)
      });
      
      console.log(`🗑️ Removed ${tokens.length} invalid FCM tokens for user ${userId}`);
    } catch (error) {
      console.error('Error removing invalid tokens:', error);
    }
  }

  /**
   * Save FCM token for a user
   */
  async saveFCMToken(userId: string, token: string): Promise<void> {
    if (!firebaseAdmin) {
      console.warn('Firebase Admin not initialized - cannot save FCM token');
      return;
    }

    try {
      const db = firebaseAdmin.firestore();
      const userRef = db.collection('users').doc(userId);
      
      // Add token if it doesn't exist (array union prevents duplicates)
      await userRef.set({
        fcmTokens: firebaseAdmin.firestore.FieldValue.arrayUnion(token),
        updatedAt: firebaseAdmin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      
      console.log(`✅ FCM token saved for user ${userId}`);
    } catch (error) {
      console.error('Error saving FCM token:', error);
      throw error;
    }
  }
}

export const notificationService = new NotificationService();
