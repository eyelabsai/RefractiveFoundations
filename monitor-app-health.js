// Health monitoring script - run weekly to catch issues early
const admin = require('firebase-admin');

// Check if already initialized
if (!admin.apps.length) {
  const serviceAccount = require('./service-account-key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function checkAppHealth() {
  try {
    console.log('🏥 Running app health check...');
    
    // Test 1: Check if we can read posts
    console.log('📝 Testing posts access...');
    const postsSnapshot = await db.collection('posts').limit(1).get();
    console.log(`✅ Posts accessible: ${postsSnapshot.size} posts found`);
    
    // Test 2: Check for users with "User" firstName
    console.log('👤 Checking for "User" profiles...');
    const userUsersSnapshot = await db.collection('users')
      .where('firstName', '==', 'User')
      .get();
    
    if (userUsersSnapshot.size > 0) {
      console.log(`⚠️  WARNING: ${userUsersSnapshot.size} users still have firstName "User"`);
      userUsersSnapshot.forEach(doc => {
        const data = doc.data();
        console.log(`   - ${data.email || 'No email'} (UID: ${doc.id})`);
      });
    } else {
      console.log('✅ No "User" profiles found');
    }
    
    // Test 3: Check total user count
    console.log('📊 Checking user statistics...');
    const allUsersSnapshot = await db.collection('users').get();
    console.log(`✅ Total users: ${allUsersSnapshot.size}`);
    
    // Test 4: Check recent notifications
    console.log('🔔 Checking recent notifications...');
    const recentNotifications = await db.collection('notifications')
      .orderBy('timestamp', 'desc')
      .limit(5)
      .get();
    console.log(`✅ Recent notifications: ${recentNotifications.size}`);
    
    console.log('🎉 Health check complete - app is healthy!');
    
  } catch (error) {
    console.error('❌ HEALTH CHECK FAILED:', error.message);
    console.error('🚨 Your app may have issues! Check Firestore rules and permissions.');
  }
  
  process.exit(0);
}

// Run the health check
checkAppHealth();
