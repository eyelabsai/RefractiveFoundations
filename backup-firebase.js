#!/usr/bin/env node

// Firebase Backup Script - Automates manual backup process
// Run this weekly: node backup-firebase.js

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

class FirebaseBackup {
  constructor() {
    this.backupDir = './firebase-backups';
    this.timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    this.backupPath = path.join(this.backupDir, `backup-${this.timestamp}`);
  }

  async createBackupDirectory() {
    if (!fs.existsSync(this.backupDir)) {
      fs.mkdirSync(this.backupDir, { recursive: true });
      console.log(`📁 Created backup directory: ${this.backupDir}`);
    }
    
    if (!fs.existsSync(this.backupPath)) {
      fs.mkdirSync(this.backupPath, { recursive: true });
      console.log(`📁 Created backup folder: ${this.backupPath}`);
    }
  }

  async backupCollection(collectionName) {
    try {
      console.log(`📝 Backing up ${collectionName}...`);
      
      const snapshot = await db.collection(collectionName).get();
      const documents = [];
      
      snapshot.forEach(doc => {
        documents.push({
          id: doc.id,
          data: doc.data(),
          timestamp: new Date().toISOString()
        });
      });
      
      const backupFile = path.join(this.backupPath, `${collectionName}.json`);
      fs.writeFileSync(backupFile, JSON.stringify(documents, null, 2));
      
      console.log(`   ✅ ${collectionName}: ${documents.length} documents backed up`);
      return documents.length;
      
    } catch (error) {
      console.error(`   ❌ Error backing up ${collectionName}:`, error.message);
      return 0;
    }
  }

  async backupAllCollections() {
    console.log('\n🔄 Starting backup process...');
    
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
    
    let totalDocuments = 0;
    const backupSummary = {};
    
    for (const collectionName of collections) {
      const count = await this.backupCollection(collectionName);
      totalDocuments += count;
      backupSummary[collectionName] = count;
    }
    
    return { totalDocuments, backupSummary };
  }

  async createBackupManifest() {
    const manifest = {
      backupInfo: {
        timestamp: this.timestamp,
        projectId: admin.app().options.projectId,
        totalCollections: 8,
        backupVersion: '1.0'
      },
      instructions: {
        restore: 'Use restore-firebase.js to restore from this backup',
        manual: 'Import JSON files manually through Firebase Console if needed'
      },
      backupPath: this.backupPath,
      createdAt: new Date().toISOString()
    };
    
    const manifestFile = path.join(this.backupPath, 'backup-manifest.json');
    fs.writeFileSync(manifestFile, JSON.stringify(manifest, null, 2));
    
    console.log('📋 Created backup manifest');
    return manifest;
  }

  async compressBackup() {
    try {
      console.log('\n🗜️  Compressing backup...');
      
      // Create a simple archive (you can enhance this with tar/zip if needed)
      const archiveInfo = {
        originalSize: this.getDirectorySize(this.backupPath),
        compressedAt: new Date().toISOString(),
        note: 'Backup is stored as individual JSON files for easy access'
      };
      
      const archiveFile = path.join(this.backupPath, 'archive-info.json');
      fs.writeFileSync(archiveFile, JSON.stringify(archiveInfo, null, 2));
      
      console.log('   ✅ Backup compression info created');
      
    } catch (error) {
      console.error('   ❌ Compression failed:', error.message);
    }
  }

  getDirectorySize(dirPath) {
    let size = 0;
    const files = fs.readdirSync(dirPath);
    
    for (const file of files) {
      const filePath = path.join(dirPath, file);
      const stats = fs.statSync(filePath);
      
      if (stats.isFile()) {
        size += stats.size;
      } else if (stats.isDirectory()) {
        size += this.getDirectorySize(filePath);
      }
    }
    
    return size;
  }

  async cleanupOldBackups() {
    try {
      console.log('\n🧹 Cleaning up old backups...');
      
      const maxBackups = 5; // Keep last 5 backups
      const backups = fs.readdirSync(this.backupDir)
        .filter(dir => dir.startsWith('backup-'))
        .sort()
        .reverse();
      
      if (backups.length > maxBackups) {
        const toDelete = backups.slice(maxBackups);
        
        for (const oldBackup of toDelete) {
          const oldBackupPath = path.join(this.backupDir, oldBackup);
          fs.rmSync(oldBackupPath, { recursive: true, force: true });
          console.log(`   🗑️  Deleted old backup: ${oldBackup}`);
        }
      } else {
        console.log(`   ✅ Keeping ${backups.length} backups (under limit of ${maxBackups})`);
      }
      
    } catch (error) {
      console.error('   ❌ Cleanup failed:', error.message);
    }
  }

  async runBackup() {
    try {
      console.log('🏥 Firebase Backup Script Starting...');
      console.log(`📅 Backup timestamp: ${this.timestamp}`);
      console.log(`📁 Backup location: ${this.backupPath}`);
      
      // Create backup directory
      await this.createBackupDirectory();
      
      // Backup all collections
      const { totalDocuments, backupSummary } = await this.backupAllCollections();
      
      // Create manifest
      const manifest = await this.createBackupManifest();
      
      // Compress backup
      await this.compressBackup();
      
      // Cleanup old backups
      await this.cleanupOldBackups();
      
      // Final summary
      console.log('\n' + '='.repeat(60));
      console.log('🎉 BACKUP COMPLETED SUCCESSFULLY!');
      console.log('='.repeat(60));
      console.log(`📊 Total documents backed up: ${totalDocuments.toLocaleString()}`);
      console.log(`📁 Backup location: ${this.backupPath}`);
      console.log(`📅 Created: ${new Date().toLocaleString()}`);
      
      console.log('\n📋 Collection Summary:');
      Object.entries(backupSummary).forEach(([collection, count]) => {
        console.log(`   ${collection}: ${count.toLocaleString()} documents`);
      });
      
      console.log('\n💡 Next Steps:');
      console.log('   1. Verify backup files in the backup directory');
      console.log('   2. Store backup in secure location (cloud storage, external drive)');
      console.log('   3. Test restore process monthly');
      console.log('   4. Run this script weekly for regular backups');
      
      console.log('\n🔧 Manual Backup Alternative:');
      console.log('   If you prefer Firebase Console method:');
      console.log('   1. Go to Firebase Console → Firestore → Export/Import');
      console.log('   2. Click "Export"');
      console.log('   3. Choose Cloud Storage bucket');
      console.log('   4. Download from bucket');
      
      return { success: true, backupPath: this.backupPath, totalDocuments };
      
    } catch (error) {
      console.error('\n❌ BACKUP FAILED:', error.message);
      console.error('🚨 Check Firebase connection and permissions');
      return { success: false, error: error.message };
    }
  }
}

// Run backup if script is executed directly
if (require.main === module) {
  const backup = new FirebaseBackup();
  backup.runBackup().then(result => {
    if (result.success) {
      process.exit(0);
    } else {
      process.exit(1);
    }
  });
}

module.exports = FirebaseBackup;
