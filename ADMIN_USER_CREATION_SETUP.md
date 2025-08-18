# 🔐 Admin-Only User Creation Setup Guide

This guide walks you through setting up admin-only user creation for RefractiveExchange, including bulk user creation from CSV files.

## 🚨 Current Status

✅ **Registration functionality has been disabled** in the mobile app  
✅ **Python bulk creation script created**  
✅ **CSV processing system ready**  

## 📋 Prerequisites

1. **Firebase Admin SDK Service Account Key**
2. **Python 3.7+** installed
3. **CSV file** with user data

## 🔧 Setup Instructions

### Step 1: Download Firebase Service Account Key

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your **RefractiveExchange** project
3. Click **⚙️ Project Settings** → **Service Accounts** tab
4. Click **Generate new private key**
5. Save the JSON file as `service-account-key.json` (keep it secure!)

### Step 2: Install Python Dependencies

```bash
# Install required packages
pip install -r requirements.txt
```

### Step 3: Prepare Your CSV File

Create a CSV file with the following columns:
- `first_name` - User's first name
- `last_name` - User's last name  
- `email` - User's email address
- `practice_name` - Name of their practice/clinic

**Example CSV format:**
```csv
first_name,last_name,email,practice_name
John,Smith,john.smith@example.com,Smith Eye Center
Sarah,Johnson,sarah.johnson@example.com,Johnson Vision Clinic
```

See `example_users.csv` for a sample file.

## 🚀 Running the Bulk User Creation

### Method 1: Using Service Account File

```bash
python bulk_user_creation.py your_users.csv service-account-key.json
```

### Method 2: Using Environment Variable

```bash
# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS="path/to/service-account-key.json"

# Run script
python bulk_user_creation.py your_users.csv
```

## 📊 What the Script Does

1. **Reads your CSV file** and validates the data
2. **Creates Firebase Auth accounts** with secure temporary passwords
3. **Creates Firestore user documents** with all required fields
4. **Generates a credentials report** (`user_credentials.csv`) with login details
5. **Provides detailed logging** and error reporting

## 📧 Distributing Credentials to Users

After running the script, you'll get a `user_credentials.csv` file containing:
- User names
- Email addresses
- Temporary passwords
- Practice names
- Firebase UIDs

**🔐 Security Notes:**
- Share credentials securely (encrypted email, secure messaging)
- Users should change passwords on first login
- Consider implementing forced password reset on first login

## 🛠️ Script Features

### ✅ Data Validation
- Email format validation
- Required field checking
- Duplicate detection

### ✅ Error Handling
- Graceful handling of existing users
- Detailed error reporting
- Partial success processing

### ✅ Security
- Secure password generation
- Firebase Admin SDK authentication
- Minimal required permissions

## 📋 Example Output

```
🚀 RefractiveExchange Bulk User Creator
========================================
📁 Processing CSV file: doctors.csv
📊 Found 25 users to process

📝 Processing user 1/25: john.smith@example.com
✅ Created Firebase Auth user: john.smith@example.com (UID: abc123...)
✅ Created Firestore document for: john.smith@example.com

...

==================================================
📊 BULK USER CREATION SUMMARY
==================================================
✅ Successfully created: 23 users
❌ Failed: 2 users
📝 Total processed: 25 users

✅ Credentials report saved to: user_credentials.csv
```

## 🔧 Troubleshooting

### Common Issues

**"Firebase Admin SDK initialization failed"**
- Check your service account key path
- Verify the JSON file is valid
- Ensure you have admin permissions

**"Email already exists"**
- User already has an account
- Script will skip and continue with others
- Check existing users in Firebase Console

**"Invalid email format"**
- Check CSV for malformed email addresses
- Ensure no extra spaces or characters

### CSV Format Issues

- Use UTF-8 encoding
- Check for extra commas or quotes
- Verify column headers match exactly

## 🔄 Re-enabling Registration (Future)

When you want to allow public registration again:

1. Uncomment the registration code in `Login.swift`:
   ```swift
   // Remove the comment blocks around the signup navigation
   ```

2. Optional: Add admin approval workflow before enabling accounts

## 🛡️ Security Best Practices

1. **Keep service account key secure** - never commit to git
2. **Use environment variables** for production
3. **Implement IP restrictions** if running from server
4. **Monitor Firebase usage** for unexpected activity
5. **Regularly rotate service account keys**

## 📞 Support

If you encounter issues:
1. Check Firebase Console for error logs
2. Verify CSV format matches requirements
3. Ensure service account has proper permissions
4. Test with a small CSV file first

---

**📝 Note:** This system gives you full control over who can access your app while maintaining a streamlined user creation process.
