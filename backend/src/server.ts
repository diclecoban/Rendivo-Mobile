import express, { Application, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { connectDatabase } from './config/database';
import routes from './routes';
import { runAppointmentReminders } from './services/reminderService';

// Load environment variables
dotenv.config();

// Create Express app
const app: Application = express();

// Middleware
app.use(cors({
  origin: [
    process.env.FRONTEND_URL || 'http://localhost:3000',
    'http://localhost:3001',
    'http://localhost:3002', // Allow port 3002
  ],
  credentials: true,
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logging middleware
app.use((req: Request, _res: Response, next: NextFunction) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// API Routes
app.use('/api', routes);

// Root endpoint
app.get('/', (_req: Request, res: Response) => {
  res.json({
    message: 'Rendivo API',
    version: '1.0.0',
    endpoints: {
      health: '/api/health',
      auth: {
        registerCustomer: 'POST /api/auth/register/customer',
        registerStaff: 'POST /api/auth/register/staff',
        registerBusiness: 'POST /api/auth/register/business',
        login: 'POST /api/auth/login',
        firebaseAuth: 'POST /api/auth/firebase',
        profile: 'GET /api/auth/profile (requires token)',
        logout: 'POST /api/auth/logout (requires token)',
      }
    }
  });
});

// 404 handler
app.use((_req: Request, res: Response) => {
  res.status(404).json({ message: 'Route not found' });
});

// Error handling middleware
app.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
  console.error('Error:', err);
  res.status(err.status || 500).json({
    message: err.message || 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err : {}
  });
});

// Start server
const PORT = process.env.PORT || 5000;

const startServer = async () => {
  try {
    // Connect to database
    await connectDatabase();
    
    // Start listening
    app.listen(PORT, () => {
      console.log(`🚀 Server is running on port ${PORT}`);
      console.log(`📝 Environment: ${process.env.NODE_ENV || 'development'}`);
      console.log(`🌐 API URL: http://localhost:${PORT}/api`);
    });

    const reminderIntervalMinutes = Number(
      process.env.REMINDER_INTERVAL_MINUTES || 60
    );
    if (reminderIntervalMinutes > 0) {
      const intervalMs = reminderIntervalMinutes * 60 * 1000;
      setInterval(() => {
        runAppointmentReminders().catch((error) =>
          console.error('Reminder job error:', error)
        );
      }, intervalMs);
      runAppointmentReminders().catch((error) =>
        console.error('Reminder job error:', error)
      );
    }
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
};

startServer();

export default app;
