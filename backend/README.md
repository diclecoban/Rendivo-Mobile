### Rendivo Backend (Express + MySQL)

1) Copy `.env.example` to `.env` and adjust values if needed.  
2) Install dependencies: `npm install`.  
3) Start the API: `npm start` (or `npm run dev` with nodemon).  

Key endpoints:
- `POST /api/auth/register` — create a customer account.
- `POST /api/auth/login` — sign in and receive a JWT.
- `GET /api/businesses` — list active businesses.
- `GET /api/businesses/:id/services` — list active services for a business.
- `GET /api/appointments/me` — authenticated; fetch customer appointments.
- `POST /api/appointments` — authenticated; create an appointment (pass `serviceIds`, `appointmentDate`, `startTime`, `endTime`, optional `notes`, `staffId`).
- `PATCH /api/appointments/:id/cancel` — authenticated; cancel own appointment.
- `PATCH /api/appointments/:id/reschedule` — authenticated; update date/time.
- `PATCH /api/appointments/:id/notes` — authenticated; update notes.
