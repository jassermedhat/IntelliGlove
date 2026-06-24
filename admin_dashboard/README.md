# IntelliGlove Admin Dashboard

This is the administrative dashboard for managing the IntelliGlove platform.

## Getting Started

1. Install dependencies: `npm install`
2. Copy `.env.example` to `.env.local` and fill out your Firebase credentials.
3. Start the dev server: `npm run dev`

## Admin Provisioning

The backend enforces that only designated administrators can access these APIs. The dashboard authenticates using Firebase Auth, but the backend requires an explicit `admin_users` record.

To provision your first admin account:

1. Sign up normally in the dashboard to generate a Firebase UID and synchronize your profile.
2. Connect directly to your local PostgreSQL database (`intelliglove`).
3. Run the following SQL to grant admin rights:

```sql
INSERT INTO admin_users (id, user_id, firebase_uid, email, role, created_at)
SELECT gen_random_uuid(), id, firebase_uid, email, 'admin', NOW()
FROM users 
WHERE email = 'your.email@example.com';
```

Without this record, the dashboard will successfully sign you in to Firebase, but any API call will return a `403 ADMIN_REQUIRED` error (handled gracefully by the dashboard UI).
