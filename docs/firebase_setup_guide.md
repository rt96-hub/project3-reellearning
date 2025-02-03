# Firebase Setup and Development Guide

This tutorial guides you through:
- **Creating a Firebase account and project**
- **Installing and connecting the Firebase CLI**
- **Creating your first database table (Firestore collection)**
- **Working with migrations and security rules**
- **Deploying Cloud Functions (APIs)**
- **Common Firebase CLI commands and workflows**

---

## 1. Create a Firebase Account & Project

1. **Sign up or log in** to [Firebase Console](https://console.firebase.google.com/).

2. **Create a new Firebase project**:
   1. Click on **Add project**.
   2. Enter your project name (e.g., *my-firebase-project*).
   3. (Optional) Enable Google Analytics if you want analytics features.
   4. **Create the project**. It may take a few seconds to set up.

Once setup completes, you’ll be redirected to your project’s **Firebase Console**.

---

## 2. Install & Configure the Firebase CLI

### 2.1 Installing Firebase CLI

The Firebase CLI is typically installed via Node.js. If you haven’t already, install **Node.js** (LTS recommended) from [nodejs.org](https://nodejs.org/).

Then, install the CLI globally:

```
npm install -g firebase-tools
```

### 2.2 Logging In & Initializing

1. **Log in to Firebase**:

   ```
   firebase login
   ```

   - This opens a browser window where you can authorize the CLI with your Google account.

2. **Navigate to your local project folder** (or create a new empty folder for your backend code), then initialize Firebase services:

   ```
   cd my_firebase_backend
   firebase init
   ```

   - The CLI will ask:
     - Which Firebase features do you want to set up? (e.g., Firestore, Functions, Hosting, etc.)
     - Which existing Firebase project do you want to use? (select your project)
   - This creates relevant config files (like `firebase.json`) in your folder.

---

## 3. Creating Your First Table / Firestore Collection

Firebase uses **NoSQL** document collections in **Cloud Firestore** rather than traditional “tables.” Here’s how to create your first collection:

1. **In the Firebase Console**, select **Firestore Database** from the left panel.
2. **Click “Create Database”** if you haven’t already. Choose production or test mode, then set location.
3. **Create a Collection**:
   - Name it (e.g., `users`) and add a sample document for testing if desired.

### 3.1 Accessing Firestore Programmatically

If you’re using Cloud Functions or a Node.js script:

```
const admin = require('firebase-admin');

// Initialize the admin SDK (use your service account in a production environment)
admin.initializeApp();

const db = admin.firestore();

// Example: add a new document to "users"
async function addUser() {
  const docRef = await db.collection('users').add({
    name: 'Alice',
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
  console.log('New user added with ID:', docRef.id);
}

addUser();
```

---

## 4. Migrations and Security Rules

### 4.1 Firestore Security Rules

Firestore uses **security rules** to control read and write access. When you initialized your project, you might see a `firestore.rules` file. Example:

```
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

- **Edit** these rules based on your security needs.  
- Deploy them via:
  ```
  firebase deploy --only firestore:rules
  ```

### 4.2 Migrations

Because Firestore is schemaless, you don’t have traditional “migrations” like SQL. However, you can:

1. **Create scripts** to transform or seed data.  
2. Run them locally or via a Cloud Function.  
3. Keep them versioned in your repository.

For example, you might have a script named `migrate-v1.js` that updates certain documents.

---

## 5. Deploying Functions (APIs)

Cloud Functions let you run backend Node.js code without managing servers.

1. **Initialize Functions**:
   - If not done during `firebase init`, you can re-run:
     ```
     firebase init functions
     ```

2. **Write a sample function** in `functions/index.js`:

   ```
   const functions = require("firebase-functions");
   const admin = require("firebase-admin");

   admin.initializeApp();

   exports.helloWorld = functions.https.onRequest((req, res) => {
     res.send("Hello from Firebase Cloud Functions!");
   });
   ```

3. **Deploy** your functions:
   ```
   cd functions
   npm install
   cd ..
   firebase deploy --only functions
   ```

4. **Test** your function by visiting the generated URL (listed in the CLI output).

---

## 6. Common Commands & Workflows

| Command                                              | Purpose                                          |
|------------------------------------------------------|--------------------------------------------------|
| ```firebase login```                          | Logs you into Firebase                           |
| ```firebase logout```                         | Logs out of Firebase                             |
| ```firebase init```                           | Initializes Firebase features in your folder     |
| ```firebase deploy```                         | Deploys **all** features (Hosting, Functions, etc.) |
| ```firebase deploy --only functions```        | Deploys only functions                           |
| ```firebase deploy --only firestore:rules```  | Deploys only Firestore security rules            |
| ```firebase emulator:start```                 | Runs local emulators for Firestore, Functions, etc. |
| ```firebase apps:list```                      | Lists all your Firebase apps                     |
| ```firebase use <project_alias>```            | Switches the CLI context to a specific project   |

---

## 7. Next Steps

1. **Authentication**: Integrate Firebase Auth for secure sign-in methods.  
2. **Hosting**: Deploy a web or admin panel to Firebase Hosting.  
3. **Realtime Database or Firestore**: Compare which database fits your use case if performance or structure needs differ.  
4. **Analytics and Crashlytics**: If you link your mobile app to Firebase, you can track events and crashes.  
5. **CI/CD**: Automate your deployments to staging or production with GitHub Actions or other CI tools.

---

### Quick Workflow Example

1. **Develop** new function in `/functions/index.js`.  
2. **Test** locally with the emulator:
   ```
   firebase emulator:start
   ```
3. **Update Firestore rules** in `firestore.rules`.  
4. **Deploy** your changes to production:
   ```
   firebase deploy
   ```

---

**You’re all set!** This guide should help you create and manage a Firebase project with Firestore, Cloud Functions, and security rules. For more advanced topics (e.g., environment variables, monitoring, or advanced security rules), consult the [Firebase documentation](https://firebase.google.com/docs).  