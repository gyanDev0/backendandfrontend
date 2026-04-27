# Secure BLE Attendance System

## Backend Architecture
- **Framework**: Node.js + Express + TypeScript
- **Database**: Firebase Firestore
- **Security**: 
  - Password Hashing: `bcrypt`
  - Auth Token: `jsonwebtoken` (JWT)
  - ID Broadcasting: `SHA256` Cryptographic Rolling Hash (Changes every 30 seconds)

## Setup Instructions

### Firebase Setup Requirement
Your backend relies on Firebase Admin to securely access the Firestore database! Before starting:
1. Open your Firebase Project Settings -> Service Accounts.
2. Generate a new private key.
3. Save the downloaded JSON file strictly as **`serviceAccountKey.json`** inside this `backend/` folder.
*Note: The server will start without it, but database queries will return an initialized error until it is placed.*

### Backend Local Setup
1. Open terminal in `backend/` folder.
2. Run `npm install` to ensure all packages are installed.
3. Run `npx tsc` or use `npm run dev` (with ts-node/nodemon) to start the server!

### To verify the Hash Algorithm standalone:
Run `node verify_hash.js` in the backend folder.
