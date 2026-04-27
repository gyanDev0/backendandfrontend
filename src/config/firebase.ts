import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';

 // Load service account from environment variable (for Render) or local file (for dev)
 let db: admin.firestore.Firestore;
 
 try {
   const envServiceAccount = process.env.FIREBASE_SERVICE_ACCOUNT;
   
   if (envServiceAccount) {
     // Production Mode: Use environment variable
     const serviceAccount = JSON.parse(envServiceAccount);
     admin.initializeApp({
       credential: admin.credential.cert(serviceAccount)
     });
     db = admin.firestore();
     console.log('Firebase Admin initialized via ENVIRONMENT VARIABLE (Production Mode).');
   } else {
     // Development Mode: Use local file
     const serviceAccountPath = path.resolve(__dirname, '../../serviceAccountKey.json');
     if (fs.existsSync(serviceAccountPath)) {
       const serviceAccount = require(serviceAccountPath);
       admin.initializeApp({
         credential: admin.credential.cert(serviceAccount)
       });
       db = admin.firestore();
       console.log('Firebase Admin initialized via LOCAL FILE (Development Mode).');
     } else {
       throw new Error('No Firebase Service Account found in environment or local file.');
     }
   }
 } catch (error) {
   console.error('CRITICAL: Firebase initialization failed:', error);
   db = null as any;
 }

export { admin, db };
