#!/usr/bin/env node

// System announcement sender - notifications appear as from the app, not a user
// No personal account involved, pure app notifications

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'refractiveexchange'
});

async function sendSystemAnnouncement(title, body) {
  try {
    console.log('📢 Sending system announcement...');
    console.log(`📋 Title: ${title}`);
    console.log(`📝 Message: ${body}`);
    
    // Admin key for system announcements (no personal account needed)
    const adminKey = 'RefractiveExchange2024Admin';
    
    // Call the system announcement function
    const functions = admin.functions();
    const systemFunction = functions.httpsCallable('systemAnnouncement');
    
    const result = await systemFunction({
      adminKey: adminKey,
      title: title,
      body: body
    });
    
    console.log('✅ System announcement sent successfully!');
    console.log(`📊 Results: ${result.data.successCount} delivered, ${result.data.failureCount} failed out of ${result.data.totalSent} total users`);
    console.log('📱 Notifications appear as from "RefractiveExchange" app, not from any user');
    
  } catch (error) {
    console.error('❌ Error sending system announcement:', error);
  } finally {
    process.exit(0);
  }
}

// Get command line arguments
const args = process.argv.slice(2);

if (args.length < 2) {
  console.log('📢 System Announcement Sender');
  console.log('═══════════════════════════════════════');
  console.log('Sends notifications that appear as from the app itself');
  console.log('');
  console.log('Usage:');
  console.log('  node send_system_announcement.js "Your Title" "Your message"');
  console.log('');
  console.log('Examples:');
  console.log('  node send_system_announcement.js "Session Reminder" "Join us Monday at 7 PM CST"');
  console.log('  node send_system_announcement.js "🔔 Important Update" "New features available in the app"');
  console.log('  node send_system_announcement.js "Welcome!" "Thanks for joining RefractiveExchange"');
  console.log('');
  console.log('Note: These notifications will NOT show your name or profile');
  console.log('      They appear as system notifications from the app');
  process.exit(1);
}

const title = args[0];
const body = args[1];

// Send the system announcement
sendSystemAnnouncement(title, body);
