const bcrypt = require('bcryptjs');
const mysql = require('mysql2/promise');
require('dotenv').config();

async function createAdmin() {
  // Create database connection
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 3306,
    database: process.env.DB_NAME || 'rendivo',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : undefined,
  });

  try {
    console.log('Connected to database');

    // Hash the password
    const hashedPassword = await bcrypt.hash('jD5sHV123', 10);
    console.log('Password hashed');

    // Insert admin user (MySQL syntax)
    const query = `
      INSERT INTO users (
        email, 
        password, 
        full_name,
        role, 
        auth_provider, 
        email_verified, 
        is_active, 
        created_at, 
        updated_at
      ) VALUES (
        ?, ?, ?, ?, ?, ?, ?, NOW(), NOW()
      )
      ON DUPLICATE KEY UPDATE 
        role = VALUES(role), 
        password = VALUES(password);
    `;

    const [result] = await connection.execute(query, [
      'rendivoapp@gmail.com',
      hashedPassword,
      'RendivoApp',
      'admin',
      'local',
      1,
      1
    ]);

    console.log('✓ Admin user created successfully!');
    console.log('Email: rendivoapp@gmail.com');
    console.log('Role: admin');
    console.log('Affected rows:', result.affectedRows);
    console.log('\nYou can now login with:');
    console.log('Email: rendivoapp@gmail.com');
    console.log('Password: jD5sHV123');

  } catch (error) {
    console.error('Error creating admin user:', error);
  } finally {
    await connection.end();
    console.log('Database connection closed');
  }
}

createAdmin();
