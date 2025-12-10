# Rendivo Backend API

Backend server for Rendivo appointment booking system with support for multiple user types and authentication methods.

## Features

- **Multiple User Types**: Customer, Staff, Business Owner
- **Multiple Authentication Methods**: 
  - Local authentication (email/password)
  - Firebase authentication (Google, Facebook, Apple)
- **MySQL Database** with Sequelize ORM
- **JWT Token Authentication**
- **Role-based Access Control**
- **Input Validation**
- **TypeScript** for type safety

## Prerequisites

- Node.js (v16 or higher)
- MySQL (v8 or higher)
- npm or yarn

## Installation

1. Install dependencies:
```bash
npm install
```

2. Create MySQL database:
```sql
CREATE DATABASE rendivo;
```

3. Configure environment variables:
```bash
cp .env.example .env
```

Edit `.env` file with your configuration:
- Database credentials
- JWT secret
- Firebase credentials (optional)
- Other settings

4. Start the development server:
```bash
npm run dev
```

The server will start on `http://localhost:5000`

## API Endpoints

### Authentication

#### Register Customer
```http
POST /api/auth/register/customer
Content-Type: application/json

{
  "email": "customer@example.com",
  "password": "password123",
  "firstName": "John",
  "lastName": "Doe",
  "phone": "1234567890"
}
```

#### Register Staff
```http
POST /api/auth/register/staff
Content-Type: application/json

{
  "email": "staff@example.com",
  "password": "password123",
  "fullName": "Jane Smith",
  "businessId": "BIZ123456789"
}
```

#### Register Business
```http
POST /api/auth/register/business
Content-Type: application/json

{
  "email": "owner@example.com",
  "password": "password123",
  "fullName": "Business Owner",
  "businessName": "My Business",
  "businessType": "Salon",
  "address": "123 Main St",
  "city": "New York",
  "state": "NY",
  "zipCode": "10001",
  "phone": "1234567890",
  "website": "https://mybusiness.com"
}
```

#### Login
```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}
```

#### Firebase Authentication
```http
POST /api/auth/firebase
Content-Type: application/json

{
  "firebaseToken": "firebase_id_token_here",
  "role": "customer",
  "additionalData": {
    "fullName": "John Doe",
    "phone": "1234567890"
  }
}
```

#### Get Profile (Protected)
```http
GET /api/auth/profile
Authorization: Bearer your_jwt_token_here
```

#### Logout (Protected)
```http
POST /api/auth/logout
Authorization: Bearer your_jwt_token_here
```

## Database Schema

### Users Table
- id (Primary Key)
- email (Unique)
- password (Hashed)
- firstName / lastName / fullName
- phone
- role (customer, staff, business_owner)
- authProvider (local, firebase, google, facebook, apple)
- firebaseUid (for Firebase users)
- emailVerified
- isActive
- lastLogin
- createdAt / updatedAt

### Businesses Table
- id (Primary Key)
- ownerId (Foreign Key to Users)
- businessName
- businessType
- description
- address, city, state, zipCode, country
- phone, email, website
- logo
- businessId (Unique identifier for staff to join)
- isActive
- createdAt / updatedAt

### StaffMembers Table
- id (Primary Key)
- userId (Foreign Key to Users)
- businessId (Foreign Key to Businesses)
- position
- isActive
- joinedAt
- createdAt / updatedAt

## Development

### Build for production:
```bash
npm run build
```

### Start production server:
```bash
npm start
```

## Environment Variables

See `.env.example` for all available configuration options.

## Security

- Passwords are hashed using bcrypt
- JWT tokens for authentication
- Input validation on all endpoints
- Role-based access control
- CORS protection

## License

ISC
