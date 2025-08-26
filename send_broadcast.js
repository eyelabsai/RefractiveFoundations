#!/usr/bin/env node

// Flexible broadcast notification script
// Send any custom message to all users

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'refractiveexchange'
});

async function sendBroadcast(title, body) {
  try {
    console.log('🔔 Sending broadcast notification...');
    console.log(`📋 Title: ${title}`);
    console.log(`📝 Message: ${body}`);
    
    // Your admin user ID
    const adminUserId = 'DV17W9np8BhGKu5erUz0Ue0KXXl2';
    
    // Call the broadcast function
    const functions = admin.functions();
    const broadcastFunction = functions.httpsCallable('broadcastNotification');
    
    const result = await broadcastFunction({
      adminUserId: adminUserId,
      title: title,
      body: body
    });
    
    console.log('✅ Broadcast sent successfully!');
    console.log(`📊 Results: ${result.data.successCount} delivered, ${result.data.failureCount} failed out of ${result.data.totalSent} total users`);
    
  } catch (error) {
    console.error('❌ Error sending broadcast:', error);
  } finally {
    process.exit(0);
  }
}

// Get command line arguments
const args = process.argv.slice(2);

if (args.length < 2) {
  console.log('📢 Broadcast Notification Sender');
  console.log('');
  console.log('Usage:');
  console.log('  node send_broadcast.js "Your Title" "Your message body"');
  console.log('');
  console.log('Examples:');
  console.log('  node send_broadcast.js "Meeting Tomorrow" "Don\'t forget our session at 7 PM CST"');
  console.log('  node send_broadcast.js "🔔 Important Update" "New guidelines have been posted in the app"');
  console.log('  node send_broadcast.js "Welcome!" "Thanks for joining RefractiveExchange community"');
  console.log('');
  process.exit(1);
}

const title = args[0];
const body = args[1];

// Send the broadcast
sendBroadcast(title, body);

