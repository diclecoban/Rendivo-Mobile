import dotenv from 'dotenv';
import { User } from './src/models';
import { UserRole, AuthProvider } from './src/models/User';
import sequelize from './src/config/database';

dotenv.config();

async function createAdmin() {
  try {
    // Connect to database
    await sequelize.authenticate();
    console.log('Connected to database');

    // Check if admin user already exists
    const existingAdmin = await User.findOne({ where: { email: 'rendivoapp@gmail.com' } });

    if (existingAdmin) {
      console.log('Admin user already exists, updating...');
      // Update existing user
      await existingAdmin.update({
        password: 'jD5sHV123', // Will be auto-hashed by beforeUpdate hook
        fullName: 'RendivoApp',
        role: UserRole.ADMIN,
        authProvider: AuthProvider.LOCAL,
        emailVerified: true,
        isActive: true,
      });
      console.log('✓ Admin user updated successfully!');
    } else {
      // Create new admin user
      const adminUser = await User.create({
        email: 'rendivoapp@gmail.com',
        password: 'jD5sHV123', // Will be auto-hashed by beforeCreate hook
        fullName: 'RendivoApp',
        role: UserRole.ADMIN,
        authProvider: AuthProvider.LOCAL,
        emailVerified: true,
        isActive: true,
      });
      console.log('✓ Admin user created successfully!');
      console.log('ID:', adminUser.id);
    }

    console.log('\nAdmin credentials:');
    console.log('Email: rendivoapp@gmail.com');
    console.log('Password: jD5sHV123');
    console.log('Role: admin');
    console.log('\nYou can now login at /login');

  } catch (error) {
    console.error('Error creating admin user:', error);
  } finally {
    await sequelize.close();
    console.log('Database connection closed');
  }
}

createAdmin();
