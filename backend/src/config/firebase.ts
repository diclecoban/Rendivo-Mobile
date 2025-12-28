import admin from 'firebase-admin';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';

const envPath = path.resolve(__dirname, '../../.env');
dotenv.config({ path: envPath });

const loadServiceAccount = (): admin.ServiceAccount | null => {
  const inlineAccount = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (inlineAccount) {
    try {
      return JSON.parse(inlineAccount);
    } catch (error) {
      console.error('Failed to parse FIREBASE_SERVICE_ACCOUNT:', error);
      return null;
    }
  }

  const rawPath =
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH ||
    process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!rawPath) return null;

  const resolvedPath = path.isAbsolute(rawPath)
    ? rawPath
    : path.resolve(process.cwd(), rawPath);
  if (!fs.existsSync(resolvedPath)) {
    console.error(`Firebase service account not found: ${resolvedPath}`);
    return null;
  }

  try {
    const file = fs.readFileSync(resolvedPath, 'utf8');
    return JSON.parse(file);
  } catch (error) {
    console.error('Failed to read Firebase service account:', error);
    return null;
  }
};

const initializeFirebase = () => {
  try {
    if (admin.apps.length) {
      return admin;
    }

    const serviceAccount = loadServiceAccount();
    if (!serviceAccount) {
      console.warn('Firebase not initialized - no service account provided');
      return null;
    }

    const projectId =
      process.env.FIREBASE_PROJECT_ID ||
      (serviceAccount as { project_id?: string }).project_id ||
      serviceAccount.projectId;
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId,
    });

    console.log('Firebase Admin initialized successfully');
    return admin;
  } catch (error) {
    console.error('Error initializing Firebase:', error);
    return null;
  }
};

export const firebaseAdmin = initializeFirebase();
export default firebaseAdmin;
