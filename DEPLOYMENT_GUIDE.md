# 🚀 Deployment Guide for Admin User Creation System

## 📋 Quick Setup Checklist

### ✅ What's Already Done
- ✅ Registration disabled in iOS app
- ✅ Python bulk creation script created
- ✅ Firebase Cloud Functions added
- ✅ Web admin interface created
- ✅ CSV processing system ready

### 🔧 What You Need to Do

## 1. Set Up Firebase Admin Collection

First, make yourself an admin in Firebase:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Open your RefractiveExchange project
3. Go to **Firestore Database**
4. Create a new collection called `admins`
5. Add a document with your user UID as the document ID:
   ```
   Collection: admins
   Document ID: [Your Firebase Auth UID]
   Fields: 
   - role: "admin"
   - created: [current timestamp]
   ```

To find your UID:
- Sign into your app normally
- Go to Firebase Console → Authentication → Users
- Find your email and copy the UID

## 2. Deploy Cloud Functions

```bash
# Navigate to functions directory
cd functions

# Install dependencies (if not already done)
npm install

# Deploy to Firebase
firebase deploy --only functions

# You should see output like:
# ✔ functions[createUser(us-central1)]
# ✔ functions[createBulkUsers(us-central1)]
```

## 3. Set Up Service Account for Python Script

1. **Download Service Account Key:**
   - Firebase Console → Project Settings → Service Accounts
   - Click "Generate new private key"
   - Save as `service-account-key.json`
   - **Keep this file secure and never commit to git!**

2. **Install Python Dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

## 4. Update Web Interface Firebase Config

Edit `admin_user_creation.html` and add your Firebase config:

```javascript
const firebaseConfig = {
    apiKey: "your-api-key",
    authDomain: "your-project.firebaseapp.com",
    projectId: "your-project-id",
    storageBucket: "your-project.appspot.com",
    messagingSenderId: "123456789",
    appId: "your-app-id"
};
```

You can find this in Firebase Console → Project Settings → General → Firebase SDK snippet

## 🎯 Usage Options

### Option 1: Python Script (Recommended for Bulk)

```bash
# Create users from CSV
python bulk_user_creation.py your_users.csv service-account-key.json

# This will create:
# - user_credentials.csv (with login details)
# - Detailed console output
```

### Option 2: Web Interface (Easy for Single Users)

1. Open `admin_user_creation.html` in a web browser
2. Sign in with your admin account
3. Create single users or upload CSV for bulk creation
4. Download credentials report

### Option 3: Cloud Functions (Programmatic)

Call the functions directly from your app or scripts:

```javascript
// Create single user
const createUser = httpsCallable(functions, 'createUser');
const result = await createUser({
    firstName: "John",
    lastName: "Doe", 
    email: "john@example.com",
    practiceName: "Doe Eye Center",
    tempPassword: "TempPass123!"
});
```

## 📊 CSV Format Requirements

Your CSV file must have these exact column headers:
```csv
first_name,last_name,email,practice_name
John,Smith,john.smith@example.com,Smith Eye Center
Sarah,Johnson,sarah.johnson@example.com,Johnson Vision Clinic
```

## 🔐 Security Features

- **Admin-only access** via Firebase rules
- **Secure password generation** (12+ characters)
- **Email validation** and duplicate checking
- **Secure credential distribution** via encrypted reports
- **Audit logging** via Firebase Functions logs

## 🎉 What Users Get

Each created user receives:
- **Email address** (their login username)
- **Temporary password** (they should change this)
- **Full access** to RefractiveExchange
- **Default specialty** set to "General Ophthalmology" 
- **Practice name** from your CSV

## 📧 Distributing Credentials

The system generates `user_credentials.csv` with:
- Name
- Email
- Temporary password
- Practice name
- Firebase UID

**Security recommendations:**
- Share via encrypted email
- Use secure messaging apps
- Consider printing and mailing for sensitive practices
- Instruct users to change passwords immediately

## 🔄 Re-enabling Public Registration

When ready to allow public signups:

1. Edit `RefractiveExchange/Not Logged In/Login.swift`
2. Uncomment the signup navigation code
3. Update the message for users

## 🛠️ Troubleshooting

### "Permission denied" errors
- Verify you're in the `admins` collection
- Check Firebase rules allow admin access
- Ensure Cloud Functions are deployed

### CSV parsing issues
- Check file encoding (use UTF-8)
- Verify column headers match exactly
- Remove extra spaces or special characters

### Firebase connection issues
- Verify service account key is valid
- Check internet connection
- Ensure project ID is correct

## 📞 Next Steps

1. **Test with a small CSV** (2-3 users) first
2. **Verify users can log in** with temporary passwords
3. **Set up password reset flow** for users
4. **Monitor Firebase usage** for any issues
5. **Create backup admin accounts** for redundancy

---

Your admin-only user creation system is now ready! 🎉
