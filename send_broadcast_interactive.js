#!/usr/bin/env node

// Interactive broadcast notification sender
// Prompts you for title and message

const admin = require('firebase-admin');
const readline = require('readline');

// Initialize Firebase Admin
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'refractiveexchange'
});

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function askQuestion(question) {
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      resolve(answer);
    });
  });
}

async function sendBroadcast(title, body) {
  try {
    console.log('\n🔔 Sending broadcast notification...');
    
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
  }
}

async function main() {
  console.log('📢 Interactive Broadcast Notification Sender');
  console.log('═══════════════════════════════════════════');
  
  try {
    const title = await askQuestion('\n📋 Enter notification title: ');
    if (!title.trim()) {
      console.log('❌ Title cannot be empty');
      rl.close();
      return;
    }
    
    const body = await askQuestion('📝 Enter notification message: ');
    if (!body.trim()) {
      console.log('❌ Message cannot be empty');
      rl.close();
      return;
    }
    
    console.log('\n📋 Preview:');
    console.log(`Title: ${title}`);
    console.log(`Message: ${body}`);
    
    const confirm = await askQuestion('\n❓ Send this notification to all users? (yes/no): ');
    
    if (confirm.toLowerCase() === 'yes' || confirm.toLowerCase() === 'y') {
      await sendBroadcast(title, body);
    } else {
      console.log('❌ Broadcast cancelled');
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    rl.close();
  }
}

main();

