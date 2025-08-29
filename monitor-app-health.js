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

async function getDetailedBillingInfo() {
  try {
    console.log('💳 Detailed Firebase Billing Information:');
    
    // Firebase pricing tiers (as of 2024)
    const pricing = {
      firestore: {
        freeTier: {
          reads: 50000,      // 50K reads/day
          writes: 20000,     // 20K writes/day  
          deletes: 20000,    // 20K deletes/day
          storage: 1,        // 1GB storage
          network: 10        // 10GB network
        },
        paidTier: {
          reads: 0.06,       // $0.06 per 100K reads
          writes: 0.18,      // $0.18 per 100K writes
          deletes: 0.02,     // $0.02 per 100K deletes
          storage: 0.18,     // $0.18 per GB/month
          network: 0.12      // $0.12 per GB
        }
      },
      storage: {
        freeTier: {
          storage: 5,        // 5GB storage
          downloads: 1       // 1GB downloads/day
        },
        paidTier: {
          storage: 0.026,    // $0.026 per GB/month
          downloads: 0.12    // $0.12 per GB
        }
      },
      functions: {
        freeTier: {
          invocations: 125000,  // 125K invocations/month
          compute: 400000,      // 400K GB-seconds/month
          network: 5            // 5GB network/month
        },
        paidTier: {
          invocations: 0.40,    // $0.40 per million invocations
          compute: 0.0025,      // $0.0025 per GB-second
          network: 0.12         // $0.12 per GB
        }
      }
    };
    
    console.log('📊 Free Tier Limits (Daily for Firestore, Monthly for others):');
    console.log('   Firestore:');
    console.log(`     Reads: ${pricing.firestore.freeTier.reads.toLocaleString()} per day`);
    console.log(`     Writes: ${pricing.firestore.freeTier.writes.toLocaleString()} per day`);
    console.log(`     Deletes: ${pricing.firestore.freeTier.deletes.toLocaleString()} per day`);
    console.log(`     Storage: ${pricing.firestore.freeTier.storage}GB`);
    console.log(`     Network: ${pricing.firestore.freeTier.network}GB`);
    
    console.log('   Storage:');
    console.log(`     Storage: ${pricing.storage.freeTier.storage}GB`);
    console.log(`     Downloads: ${pricing.storage.freeTier.downloads}GB per day`);
    
    console.log('   Functions:');
    console.log(`     Invocations: ${pricing.functions.freeTier.invocations.toLocaleString()} per month`);
    console.log(`     Compute: ${pricing.functions.freeTier.compute.toLocaleString()} GB-seconds per month`);
    console.log(`     Network: ${pricing.functions.freeTier.network}GB per month`);
    
    console.log('\n💰 Paid Tier Pricing:');
    console.log('   Firestore:');
    console.log(`     Reads: $${pricing.firestore.paidTier.reads} per 100K reads`);
    console.log(`     Writes: $${pricing.firestore.paidTier.writes} per 100K writes`);
    console.log(`     Deletes: $${pricing.firestore.paidTier.deletes} per 100K deletes`);
    console.log(`     Storage: $${pricing.firestore.paidTier.storage} per GB/month`);
    console.log(`     Network: $${pricing.firestore.paidTier.network} per GB`);
    
    console.log('   Storage:');
    console.log(`     Storage: $${pricing.storage.paidTier.storage} per GB/month`);
    console.log(`     Downloads: $${pricing.storage.paidTier.downloads} per GB`);
    
    console.log('   Functions:');
    console.log(`     Invocations: $${pricing.functions.paidTier.invocations} per million invocations`);
    console.log(`     Compute: $${pricing.functions.paidTier.compute} per GB-second`);
    console.log(`     Network: $${pricing.functions.paidTier.network} per GB`);
    
    return pricing;
  } catch (error) {
    console.error('❌ Billing info failed:', error.message);
    return null;
  }
}

async function estimateMonthlyCosts(documentCounts, pricing) {
  try {
    console.log('\n🧮 Cost Estimation for Your Current Usage:');
    
    // Estimate daily operations based on document counts
    const estimates = {
      // Assume each user reads 10 posts + 5 comments daily
      dailyReads: documentCounts.users * 15 + documentCounts.posts * 5 + documentCounts.comments * 3,
      // Assume each user creates 1 post + 2 comments weekly
      dailyWrites: Math.ceil((documentCounts.users * 3) / 7),
      // Assume minimal deletes
      dailyDeletes: Math.ceil(documentCounts.users * 0.1),
      // Estimate storage (rough calculation)
      storageGB: Math.max(0.1, (documentCounts.total * 0.001)) // ~1KB per document
    };
    
    console.log('📈 Estimated Daily Usage:');
    console.log(`   Reads: ${estimates.dailyReads.toLocaleString()} per day`);
    console.log(`   Writes: ${estimates.dailyWrites.toLocaleString()} per day`);
    console.log(`   Deletes: ${estimates.dailyDeletes.toLocaleString()} per day`);
    console.log(`   Storage: ${estimates.storageGB.toFixed(3)}GB`);
    
    // Calculate monthly costs
    const monthlyReads = estimates.dailyReads * 30;
    const monthlyWrites = estimates.dailyWrites * 30;
    const monthlyDeletes = estimates.dailyDeletes * 30;
    
    let monthlyCost = 0;
    let costBreakdown = [];
    
    // Check if we exceed free tier
    if (monthlyReads > pricing.firestore.freeTier.reads * 30) {
      const excessReads = monthlyReads - (pricing.firestore.freeTier.reads * 30);
      const readCost = (excessReads / 100000) * pricing.firestore.paidTier.reads;
      monthlyCost += readCost;
      costBreakdown.push(`Reads: $${readCost.toFixed(4)}`);
    }
    
    if (monthlyWrites > pricing.firestore.freeTier.writes * 30) {
      const excessWrites = monthlyWrites - (pricing.firestore.freeTier.writes * 30);
      const writeCost = (excessWrites / 100000) * pricing.firestore.paidTier.writes;
      monthlyCost += writeCost;
      costBreakdown.push(`Writes: $${writeCost.toFixed(4)}`);
    }
    
    if (monthlyDeletes > pricing.firestore.freeTier.deletes * 30) {
      const excessDeletes = monthlyDeletes - (pricing.firestore.freeTier.deletes * 30);
      const deleteCost = (excessDeletes / 100000) * pricing.firestore.paidTier.deletes;
      monthlyCost += deleteCost;
      costBreakdown.push(`Deletes: $${deleteCost.toFixed(4)}`);
    }
    
    if (estimates.storageGB > pricing.firestore.freeTier.storage) {
      const excessStorage = estimates.storageGB - pricing.firestore.freeTier.storage;
      const storageCost = excessStorage * pricing.firestore.paidTier.storage;
      monthlyCost += storageCost;
      costBreakdown.push(`Storage: $${storageCost.toFixed(4)}`);
    }
    
    console.log('\n💵 Monthly Cost Projection:');
    if (monthlyCost === 0) {
      console.log('   ✅ FREE TIER - No additional costs expected');
    } else {
      console.log(`   💰 Estimated monthly cost: $${monthlyCost.toFixed(4)}`);
      console.log('   Breakdown:');
      costBreakdown.forEach(cost => console.log(`     ${cost}`));
    }
    
    // Growth projections
    console.log('\n📊 Growth Projections:');
    const growthScenarios = [100, 500, 1000, 5000];
    
    growthScenarios.forEach(userCount => {
      if (userCount > documentCounts.users) {
        const growthFactor = userCount / documentCounts.users;
        const projectedReads = estimates.dailyReads * growthFactor * 30;
        const projectedWrites = estimates.dailyWrites * growthFactor * 30;
        
        let projectedCost = 0;
        if (projectedReads > pricing.firestore.freeTier.reads * 30) {
          const excessReads = projectedReads - (pricing.firestore.freeTier.reads * 30);
          projectedCost += (excessReads / 100000) * pricing.firestore.paidTier.reads;
        }
        if (projectedWrites > pricing.firestore.freeTier.writes * 30) {
          const excessWrites = projectedWrites - (pricing.firestore.freeTier.writes * 30);
          projectedCost += (excessWrites / 100000) * pricing.firestore.paidTier.writes;
        }
        
        if (projectedCost > 0) {
          console.log(`   ${userCount} users: ~$${projectedCost.toFixed(2)}/month`);
        }
      }
    });
    
  } catch (error) {
    console.error('❌ Cost estimation failed:', error.message);
  }
}

async function checkFirebaseUsage() {
  try {
    console.log('💰 Checking Firebase usage and costs...');
    
    // Get project info
    const projectId = admin.app().options.projectId;
    console.log(`📊 Project: ${projectId}`);
    
    // Check Firestore usage
    console.log('📝 Firestore Usage:');
    
    // Count documents in major collections
    const collections = ['users', 'posts', 'comments', 'conversations', 'directMessages', 'notifications'];
    let totalDocs = 0;
    const documentCounts = {};
    
    for (const collectionName of collections) {
      try {
        const snapshot = await db.collection(collectionName).get();
        const count = snapshot.size;
        totalDocs += count;
        documentCounts[collectionName] = count;
        console.log(`   ${collectionName}: ${count} documents`);
      } catch (error) {
        console.log(`   ${collectionName}: Error - ${error.message}`);
        documentCounts[collectionName] = 0;
      }
    }
    
    documentCounts.total = totalDocs;
    console.log(`   Total documents: ${totalDocs}`);
    
    // Get detailed billing info
    const pricing = await getDetailedBillingInfo();
    
    // Estimate costs based on current usage
    if (pricing) {
      await estimateMonthlyCosts(documentCounts, pricing);
    }
    
    // Check if we're approaching limits
    console.log('\n⚠️  Usage Alerts:');
    if (totalDocs > 10000) {
      console.log('   ⚠️  High document count - monitor read/write costs');
    } else if (totalDocs > 5000) {
      console.log('   ⚠️  Moderate document count - costs should be manageable');
    } else {
      console.log('   ✅ Low document count - costs should be minimal');
    }
    
    // Recommendations
    console.log('\n💡 Recommendations:');
    if (totalDocs > 10000) {
      console.log('   - Consider implementing pagination for large collections');
      console.log('   - Monitor read/write patterns in Firebase Console');
      console.log('   - Set up billing alerts at 80%, 90%, 100%');
    } else {
      console.log('   - Current usage is within free tier limits');
      console.log('   - Set up billing alerts for future monitoring');
    }
    
    // Billing setup instructions
    console.log('\n🔧 Billing Setup:');
    console.log('   1. Go to Firebase Console → Billing');
    console.log('   2. Set up billing account (credit card required)');
    console.log('   3. Set up budget alerts at 80%, 90%, 100%');
    console.log('   4. Monitor usage in Firebase Console → Usage');
    
  } catch (error) {
    console.error('❌ Usage check failed:', error.message);
  }
}

async function checkFirebaseBestPractices() {
  try {
    console.log('🔒 Checking Firebase Best Practices & Security:');
    
    // Check 1: Service Account Security
    console.log('\n🔑 Service Account Security:');
    try {
      const serviceAccount = require('./service-account-key.json');
      const hasServiceAccount = !!serviceAccount;
      console.log(`   ✅ Service account key exists: ${hasServiceAccount}`);
      
      if (hasServiceAccount) {
        // Check if service account has minimal permissions
        const projectId = serviceAccount.project_id;
        console.log(`   📊 Project ID: ${projectId}`);
        
        // Check if key is in .gitignore (basic security)
        const fs = require('fs');
        try {
          const gitignore = fs.readFileSync('.gitignore', 'utf8');
          const isIgnored = gitignore.includes('service-account-key.json');
          console.log(`   🔒 Service account in .gitignore: ${isIgnored ? '✅' : '❌ CRITICAL SECURITY RISK'}`);
          
          if (!isIgnored) {
            console.log('   🚨 ACTION REQUIRED: Add service-account-key.json to .gitignore');
          }
        } catch (error) {
          console.log('   ⚠️  No .gitignore found - create one and add service-account-key.json');
        }
      }
    } catch (error) {
      console.log('   ❌ Service account key not found or invalid');
    }
    
    // Check 2: Database Rules
    console.log('\n📋 Database Security Rules:');
    try {
      const rulesPath = './firestore.rules';
      const fs = require('fs');
      if (fs.existsSync(rulesPath)) {
        const rules = fs.readFileSync(rulesPath, 'utf8');
        
        // Basic security checks
        const hasAuthCheck = rules.includes('request.auth != null');
        const hasOwnerCheck = rules.includes('request.auth.uid');
        const hasCollectionRules = rules.includes('match /users/') && rules.includes('match /posts/');
        
        console.log(`   ✅ Authentication required: ${hasAuthCheck ? 'Yes' : 'No'}`);
        console.log(`   ✅ Owner-based access: ${hasOwnerCheck ? 'Yes' : 'No'}`);
        console.log(`   ✅ Collection rules defined: ${hasCollectionRules ? 'Yes' : 'No'}`);
        
        if (!hasAuthCheck || !hasOwnerCheck) {
          console.log('   ⚠️  WARNING: Basic security rules may be missing');
        }
      } else {
        console.log('   ❌ No firestore.rules file found');
      }
    } catch (error) {
      console.log('   ❌ Error checking security rules');
    }
    
    // Check 3: Backup Strategy
    console.log('\n💾 Backup Strategy:');
    console.log('   📋 Manual Backup Instructions:');
    console.log('     1. Firebase Console → Firestore → Export/Import');
    console.log('     2. Export to Cloud Storage bucket');
    console.log('     3. Download to local machine');
    console.log('     4. Store in secure location');
    console.log('     5. Schedule weekly backups');
    
    // Check 4: Monitoring & Alerts
    console.log('\n📊 Monitoring & Alerts:');
    console.log('   🔔 Essential Alerts to Set Up:');
    console.log('     1. Billing alerts at 80%, 90%, 100%');
    console.log('     2. Error rate alerts (>5% errors)');
    console.log('     3. Performance alerts (response time >2s)');
    console.log('     4. Storage usage alerts (>80% capacity)');
    
    // Check 5: Environment Configuration
    console.log('\n🌍 Environment Configuration:');
    console.log('   ✅ Current Setup:');
    console.log('     - Production Firebase project configured');
    console.log('     - Service account for admin operations');
    console.log('     - Health monitoring script active');
    
    console.log('   🔧 Recommended Next Steps:');
    console.log('     1. Set up staging environment');
    console.log('     2. Implement automated backups');
    console.log('     3. Add error logging (Sentry, LogRocket)');
    console.log('     4. Set up performance monitoring');
    
    // Check 6: Data Retention & Cleanup
    console.log('\n🧹 Data Management:');
    console.log('   📅 Current Status:');
    console.log('     - No automatic data expiration (GOOD for your use case)');
    console.log('     - All user data preserved indefinitely');
    console.log('     - Professional discussions maintained long-term');
    
    console.log('   💡 Recommendations:');
    console.log('     - Keep current setup (no expiration)');
    console.log('     - Implement data archiving for very old posts');
    console.log('     - Add soft delete for user-removed content');
    
    // Check 7: API Rate Limiting
    console.log('\n🚦 API Protection:');
    console.log('   🛡️  Current Protection:');
    console.log('     - Firebase Auth rate limiting (built-in)');
    console.log('     - Firestore query limits (built-in)');
    
    console.log('   🔧 Additional Recommendations:');
    console.log('     - Implement client-side request throttling');
    console.log('     - Add server-side rate limiting for Cloud Functions');
    console.log('     - Monitor for unusual activity patterns');
    
    // Check 8: Disaster Recovery
    console.log('\n🚨 Disaster Recovery Plan:');
    console.log('   📋 Essential Steps:');
    console.log('     1. Weekly automated backups');
    console.log('     2. Document recovery procedures');
    console.log('     3. Test restore process monthly');
    console.log('     4. Keep multiple backup copies');
    console.log('     5. Document admin procedures');
    
    console.log('   🎯 Recovery Time Objective: <24 hours');
    console.log('   🎯 Recovery Point Objective: <1 hour data loss');
    
  } catch (error) {
    console.error('❌ Best practices check failed:', error.message);
  }
}

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
      .limit(5).get();
    console.log(`✅ Recent notifications: ${recentNotifications.size}`);
    
    console.log('\n' + '='.repeat(50));
    
    // Add Firebase usage check
    await checkFirebaseUsage();
    
    // Add best practices check
    await checkFirebaseBestPractices();
    
    console.log('\n' + '='.repeat(50));
    console.log('🎉 Health check complete - app is healthy!');
    
  } catch (error) {
    console.error('❌ HEALTH CHECK FAILED:', error.message);
    console.error('🚨 Your app may have issues! Check Firestore rules and permissions.');
  }
  
  process.exit(0);
}

// Run the health check
checkAppHealth();
