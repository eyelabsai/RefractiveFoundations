#!/usr/bin/env node

// Firebase Restore Script - Restore data from backup files
// Usage: node restore-firebase.js [backup-folder-name]
// Example: node restore-firebase.js backup-2024-01-15T10-30-00-000Z

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Check if already initialized
if (!admin.apps.length) {
  const serviceAccount = require('./service-account-key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

class FirebaseRestore {
  constructor(backupFolder) {
    this.backupDir = './firebase-backups';
    this.backupFolder = backupFolder || null; // Handle undefined case
    this.backupPath = this.backupFolder ? path.join(this.backupDir, this.backupFolder) : null;
    this.manifestPath = this.backupPath ? path.join(this.backupPath, 'backup-manifest.json') : null;
  }

  async validateBackup() {
    try {
      console.log('🔍 Validating backup...');
      
      if (!this.backupPath) {
        throw new Error('No backup folder specified or found.');
      }

      if (!fs.existsSync(this.backupPath)) {
        throw new Error(`Backup folder not found: ${this.backupPath}`);
      }
      
      if (!fs.existsSync(this.manifestPath)) {
        throw new Error(`Backup manifest not found: ${this.manifestPath}`);
      }
      
      const manifest = JSON.parse(fs.readFileSync(this.manifestPath, 'utf8'));
      console.log(`✅ Backup validated: ${manifest.backupInfo.timestamp}`);
      console.log(`📊 Project: ${manifest.backupInfo.projectId}`);
      console.log(`📁 Collections: ${manifest.backupInfo.totalCollections}`);
      
      return manifest;
      
    } catch (error) {
      console.error('❌ Backup validation failed:', error.message);
      throw error;
    }
  }

  async listAvailableBackups() {
    try {
      if (!fs.existsSync(this.backupDir)) {
        console.log('❌ No backup directory found');
        return [];
      }
      
      const backups = fs.readdirSync(this.backupDir)
        .filter(dir => dir.startsWith('backup-'))
        .sort()
        .reverse();
      
      if (backups.length === 0) {
        console.log('❌ No backups found');
        return [];
      }
      
      console.log('\n📋 Available backups:');
      backups.forEach((backup, index) => {
        const backupPath = path.join(this.backupDir, backup);
        const manifestPath = path.join(backupPath, 'backup-manifest.json');
        
        if (fs.existsSync(manifestPath)) {
          try {
            const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
            console.log(`   ${index + 1}. ${backup}`);
            console.log(`      📅 ${manifest.backupInfo.timestamp}`);
            console.log(`      📊 ${manifest.backupInfo.totalCollections} collections`);
          } catch (error) {
            console.log(`   ${index + 1}. ${backup} (manifest corrupted)`);
          }
        } else {
          console.log(`   ${index + 1}. ${backup} (no manifest)`);
        }
      });
      
      return backups;
      
    } catch (error) {
      console.error('❌ Error listing backups:', error.message);
      return [];
    }
  }

  async restoreCollection(collectionName) {
    try {
      const backupFile = path.join(this.backupPath, `${collectionName}.json`);
      
      if (!this.backupPath) {
        console.log(`   ⚠️  No backup folder specified, skipping ${collectionName}`);
        return 0;
      }

      if (!fs.existsSync(backupFile)) {
        console.log(`   ⚠️  No backup file for ${collectionName}, skipping`);
        return 0;
      }
      
      console.log(`📝 Restoring ${collectionName}...`);
      
      const backupData = JSON.parse(fs.readFileSync(backupFile, 'utf8'));
      let restoredCount = 0;
      
      for (const doc of backupData) {
        try {
          // Check if document already exists
          const existingDoc = await db.collection(collectionName).doc(doc.id).get();
          
          if (existingDoc.exists) {
            console.log(`      ⚠️  Document ${doc.id} already exists, skipping`);
            continue;
          }
          
          // Restore document
          await db.collection(collectionName).doc(doc.id).set(doc.data);
          restoredCount++;
          
        } catch (error) {
          console.error(`      ❌ Error restoring document ${doc.id}:`, error.message);
        }
      }
      
      console.log(`   ✅ ${collectionName}: ${restoredCount} documents restored`);
      return restoredCount;
      
    } catch (error) {
      console.error(`   ❌ Error restoring ${collectionName}:`, error.message);
      return 0;
    }
  }

  async restoreAllCollections() {
    console.log('\n🔄 Starting restore process...');
    
    const collections = [
      'users',
      'posts', 
      'comments',
      'conversations',
      'directMessages',
      'notifications',
      'groupChats',
      'groupMessages'
    ];
    
    let totalRestored = 0;
    const restoreSummary = {};
    
    for (const collectionName of collections) {
      const count = await this.restoreCollection(collectionName);
      totalRestored += count;
      restoreSummary[collectionName] = count;
    }
    
    return { totalRestored, restoreSummary };
  }

  async runRestore() {
    try {
      console.log('🏥 Firebase Restore Script Starting...');
      
      // If no backup folder specified, show available backups
      if (!this.backupFolder) {
        console.log('📋 No backup folder specified. Available backups:');
        const backups = await this.listAvailableBackups();
        
        if (backups.length === 0) {
          console.log('\n❌ No backups available. Run backup-firebase.js first.');
          return { success: false, error: 'No backups available' };
        }
        
        console.log('\n💡 Usage: node restore-firebase.js [backup-folder-name]');
        console.log('   Example: node restore-firebase.js backup-2024-01-15T10-30-00-000Z');
        return { success: false, error: 'No backup folder specified' };
      }
      
      console.log(`📁 Restoring from: ${this.backupPath}`);
      
      // Validate backup
      const manifest = await this.validateBackup();
      
      // Confirm restore
      console.log('\n⚠️  WARNING: This will restore data to your Firebase project!');
      console.log('   Make sure you want to restore from this backup.');
      console.log('   Existing data with the same IDs will be skipped.');
      
      // In a real scenario, you might want to add user confirmation here
      // For now, we'll proceed with the restore
      
      // Restore all collections
      const { totalRestored, restoreSummary } = await this.restoreAllCollections();
      
      // Final summary
      console.log('\n' + '='.repeat(60));
      console.log('🎉 RESTORE COMPLETED SUCCESSFULLY!');
      console.log('='.repeat(60));
      console.log(`📊 Total documents restored: ${totalRestored.toLocaleString()}`);
      console.log(`📁 Restored from: ${this.backupPath}`);
      console.log(`📅 Completed: ${new Date().toLocaleString()}`);
      
      console.log('\n📋 Collection Summary:');
      Object.entries(restoreSummary).forEach(([collection, count]) => {
        console.log(`   ${collection}: ${count.toLocaleString()} documents restored`);
      });
      
      console.log('\n💡 Next Steps:');
      console.log('   1. Verify restored data in Firebase Console');
      console.log('   2. Test app functionality');
      console.log('   3. Check for any data conflicts');
      console.log('   4. Update your backup schedule');
      
      return { success: true, totalRestored, restoreSummary };
      
    } catch (error) {
      console.error('\n❌ RESTORE FAILED:', error.message);
      return { success: false, error: error.message };
    }
  }
}

// Run restore if script is executed directly
if (require.main === module) {
  const backupFolder = process.argv[2];
  const restore = new FirebaseRestore(backupFolder);
  restore.runRestore().then(result => {
    if (result.success) {
      process.exit(0);
    } else {
      process.exit(1);
    }
  });
}

module.exports = FirebaseRestore;
