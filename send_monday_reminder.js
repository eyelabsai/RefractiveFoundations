#!/usr/bin/env node

// Script to send Monday session reminder to all users
// Run this when you're ready to send the notification

const admin = require('firebase-admin');

// Initialize Firebase Admin (make sure you have the service account key)
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'refractiveexchange'
});

async function sendMondayReminder() {
  try {
    console.log('🔔 Preparing to send Monday session reminder...');
    
    // Your user ID (replace with your actual admin user ID)
    const adminUserId = 'DV17W9np8BhGKu5erUz0Ue0KXXl2';
    
    // The reminder message
    const reminderData = {
      adminUserId: adminUserId,
      title: '📅 Reminder: Session Tomorrow!',
      body: 'Don\'t forget about our first session tomorrow (Monday, Aug 25) at 7 PM CST. See you there!'
    };
    
    // Call the broadcast function
    const broadcastFunction = admin.functions().httpsCallable('broadcastNotification');
    const result = await broadcastFunction(reminderData);
    
    console.log('✅ Broadcast notification sent successfully!');
    console.log(`📊 Results: ${result.data.successCount} sent, ${result.data.failureCount} failed out of ${result.data.totalSent} total users`);
    
  } catch (error) {
    console.error('❌ Error sending broadcast:', error);
  } finally {
    process.exit(0);
  }
}

// Uncomment the line below when you're ready to send the notification
// sendMondayReminder();

console.log('📋 Script ready! To send the Monday reminder:');
console.log('1. Uncomment the last line in this file');
console.log('2. Run: node send_monday_reminder.js');
console.log('3. Or just call the function directly from Firebase console');

