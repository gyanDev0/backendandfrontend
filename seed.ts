import { db } from './src/config/firebase';

async function seedInstitution() {
  if (!db) {
    console.error('Firebase DB not initialized. Have you added serviceAccountKey.json?');
    process.exit(1);
  }

  try {
    const institutionRef = db.collection('institutions').doc();
    await institutionRef.set({
      institution_name: 'Test University',
      institution_code: 'INST123'
    });

    console.log('✅ Successfully seeded Test Institution!');
    console.log('📌 You can now register in the app using Institution Code: INST123');
    process.exit(0);
  } catch (error) {
    console.error('Failed to seed:', error);
    process.exit(1);
  }
}

seedInstitution();
