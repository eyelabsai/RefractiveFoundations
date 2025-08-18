#!/usr/bin/env python3
"""
Bulk User Creation Script for RefractiveExchange
===============================================

This script creates Firebase users in bulk from a CSV file.
It handles both Firebase Authentication and Firestore user document creation.

Required CSV columns:
- first_name
- last_name  
- email
- practice_name

Prerequisites:
1. Install required packages: pip install firebase-admin pandas
2. Download Firebase service account key JSON file
3. Set GOOGLE_APPLICATION_CREDENTIALS environment variable
"""

import csv
import sys
import os
import secrets
import string
from typing import List, Dict, Optional
import pandas as pd
import firebase_admin
from firebase_admin import credentials, auth, firestore
from datetime import datetime

class BulkUserCreator:
    def __init__(self, service_account_path: Optional[str] = None):
        """Initialize Firebase Admin SDK."""
        try:
            if service_account_path:
                cred = credentials.Certificate(service_account_path)
            else:
                # Use GOOGLE_APPLICATION_CREDENTIALS environment variable
                cred = credentials.ApplicationDefault()
            
            firebase_admin.initialize_app(cred)
            self.db = firestore.client()
            print("✅ Firebase Admin SDK initialized successfully")
        except Exception as e:
            print(f"❌ Failed to initialize Firebase: {e}")
            sys.exit(1)

    def generate_temp_password(self, length: int = 12) -> str:
        """Generate a secure temporary password."""
        # Use fixed password for easier distribution
        return "RefractiveFoundations"

    def create_user(self, user_data: Dict) -> Dict:
        """Create a single user in Firebase Auth and Firestore."""
        try:
            # Generate temporary password
            temp_password = self.generate_temp_password()
            
            # Create user in Firebase Auth
            user_record = auth.create_user(
                email=user_data['email'],
                password=temp_password,
                display_name=f"{user_data['first_name']} {user_data['last_name']}"
            )
            
            print(f"✅ Created Firebase Auth user: {user_data['email']} (UID: {user_record.uid})")
            
            # Create user document in Firestore
            firestore_user_data = {
                'credential': '',
                'email': user_data['email'],
                'firstName': user_data['first_name'],
                'lastName': user_data['last_name'],
                'position': '',
                'specialty': 'General Ophthalmology',  # Default specialty
                'state': '',
                'suffix': '',
                'uid': user_record.uid,
                'avatarUrl': None,
                'exchangeUsername': '',  # User can set this later
                'favoriteLenses': [],
                'savedPosts': [],
                'dateJoined': firestore.SERVER_TIMESTAMP,
                'practiceLocation': '',
                'practiceName': user_data.get('practice_name', ''),
                'hasCompletedOnboarding': False,
                # Add notification preferences
                'notificationPreferences': {
                    'comments': True,
                    'directMessages': True,
                    'posts': True,
                    'mentions': True
                }
            }
            
            # Save to Firestore
            self.db.collection('users').document(user_record.uid).set(firestore_user_data)
            print(f"✅ Created Firestore document for: {user_data['email']}")
            
            return {
                'success': True,
                'email': user_data['email'],
                'uid': user_record.uid,
                'temp_password': temp_password,
                'name': f"{user_data['first_name']} {user_data['last_name']}",
                'practice_name': user_data.get('practice_name', '')
            }
            
        except auth.EmailAlreadyExistsError:
            print(f"⚠️  User already exists: {user_data['email']}")
            return {
                'success': False,
                'email': user_data['email'],
                'error': 'Email already exists',
                'name': f"{user_data['first_name']} {user_data['last_name']}",
                'practice_name': user_data.get('practice_name', '')
            }
        except Exception as e:
            print(f"❌ Failed to create user {user_data['email']}: {e}")
            return {
                'success': False,
                'email': user_data['email'],
                'error': str(e),
                'name': f"{user_data['first_name']} {user_data['last_name']}",
                'practice_name': user_data.get('practice_name', '')
            }

    def process_csv(self, csv_file_path: str) -> List[Dict]:
        """Process CSV file and create users."""
        try:
            # Read CSV file
            df = pd.read_csv(csv_file_path)
            
            # Validate required columns
            required_columns = ['first_name', 'last_name', 'email', 'practice_name']
            missing_columns = [col for col in required_columns if col not in df.columns]
            
            if missing_columns:
                print(f"❌ Missing required columns: {missing_columns}")
                print(f"Available columns: {list(df.columns)}")
                return []
            
            print(f"📊 Found {len(df)} users to process")
            
            results = []
            
            for index, row in df.iterrows():
                print(f"\n📝 Processing user {index + 1}/{len(df)}: {row['email']}")
                
                # Clean and validate data
                user_data = {
                    'first_name': str(row['first_name']).strip(),
                    'last_name': str(row['last_name']).strip(),
                    'email': str(row['email']).strip().lower(),
                    'practice_name': str(row['practice_name']).strip() if pd.notna(row['practice_name']) else ''
                }
                
                # Validate email format
                if '@' not in user_data['email'] or '.' not in user_data['email']:
                    print(f"⚠️  Invalid email format: {user_data['email']}")
                    results.append({
                        'success': False,
                        'email': user_data['email'],
                        'error': 'Invalid email format',
                        'name': f"{user_data['first_name']} {user_data['last_name']}",
                        'practice_name': user_data['practice_name']
                    })
                    continue
                
                # Create user
                result = self.create_user(user_data)
                results.append(result)
                
            return results
            
        except FileNotFoundError:
            print(f"❌ CSV file not found: {csv_file_path}")
            return []
        except Exception as e:
            print(f"❌ Error processing CSV: {e}")
            return []

    def generate_credentials_report(self, results: List[Dict], output_file: str = 'user_credentials.csv'):
        """Generate a report with user credentials."""
        try:
            successful_users = [r for r in results if r['success']]
            
            if not successful_users:
                print("❌ No users were created successfully. No credentials report generated.")
                return
            
            # Create credentials CSV
            with open(output_file, 'w', newline='', encoding='utf-8') as csvfile:
                fieldnames = ['name', 'email', 'temp_password', 'practice_name', 'uid']
                writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                
                writer.writeheader()
                for user in successful_users:
                    writer.writerow({
                        'name': user['name'],
                        'email': user['email'],
                        'temp_password': user['temp_password'],
                        'practice_name': user['practice_name'],
                        'uid': user['uid']
                    })
            
            print(f"✅ Credentials report saved to: {output_file}")
            print(f"📧 Share this file securely with users for their login credentials")
            
        except Exception as e:
            print(f"❌ Failed to generate credentials report: {e}")

    def print_summary(self, results: List[Dict]):
        """Print summary of the bulk creation process."""
        successful = [r for r in results if r['success']]
        failed = [r for r in results if not r['success']]
        
        print(f"\n{'='*50}")
        print(f"📊 BULK USER CREATION SUMMARY")
        print(f"{'='*50}")
        print(f"✅ Successfully created: {len(successful)} users")
        print(f"❌ Failed: {len(failed)} users")
        print(f"📝 Total processed: {len(results)} users")
        
        if failed:
            print(f"\n❌ Failed Users:")
            for user in failed:
                print(f"   • {user['email']} - {user.get('error', 'Unknown error')}")
        
        if successful:
            print(f"\n✅ Successful Users:")
            for user in successful[:5]:  # Show first 5
                print(f"   • {user['email']} - {user['name']}")
            if len(successful) > 5:
                print(f"   ... and {len(successful) - 5} more")


def main():
    """Main function to run the bulk user creation script."""
    print("🚀 RefractiveExchange Bulk User Creator")
    print("="*40)
    
    # Check for CSV file argument
    if len(sys.argv) < 2:
        print("Usage: python bulk_user_creation.py <csv_file_path> [service_account_path]")
        print("\nCSV file should contain columns: first_name, last_name, email, practice_name")
        print("\nExample:")
        print("  python bulk_user_creation.py users.csv")
        print("  python bulk_user_creation.py users.csv path/to/service-account.json")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    service_account_path = sys.argv[2] if len(sys.argv) > 2 else None
    
    # Verify CSV file exists
    if not os.path.exists(csv_file):
        print(f"❌ CSV file not found: {csv_file}")
        sys.exit(1)
    
    # Initialize creator
    creator = BulkUserCreator(service_account_path)
    
    # Process users
    print(f"📁 Processing CSV file: {csv_file}")
    results = creator.process_csv(csv_file)
    
    if not results:
        print("❌ No users processed. Exiting.")
        sys.exit(1)
    
    # Generate reports
    creator.print_summary(results)
    creator.generate_credentials_report(results)
    
    print(f"\n🎉 Bulk user creation completed!")
    print(f"📧 Remember to securely distribute the credentials to users")
    print(f"🔐 Users should change their passwords on first login")


if __name__ == "__main__":
    main()
