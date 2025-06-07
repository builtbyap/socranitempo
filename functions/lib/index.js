"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createCustomer = exports.onCreateUser = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
// Function to create a customer record when a new user signs up
exports.onCreateUser = functions.auth.user().onCreate(async (user) => {
    try {
        if (!user.email) {
            console.error('No email provided for user:', user.uid);
            return;
        }
        // Create customer document in Firestore
        await admin.firestore().collection('customers').doc(user.uid).set({
            email: user.email,
            created: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log('Customer document created successfully for user:', user.uid);
    }
    catch (error) {
        console.error('Error creating customer document:', error);
        throw error;
    }
});
// Function to handle customer creation via HTTP endpoint
exports.createCustomer = functions.https.onCall(async (data, context) => {
    try {
        // Check if user is authenticated
        if (!context.auth) {
            throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to create a customer record');
        }
        const { email } = data;
        const userId = context.auth.uid;
        if (!email) {
            throw new functions.https.HttpsError('invalid-argument', 'Email is required');
        }
        // Check if customer already exists
        const customerDoc = await admin.firestore().collection('customers').doc(userId).get();
        if (customerDoc.exists) {
            console.log('Customer already exists for user:', userId);
            return { success: true };
        }
        // Create customer document
        await admin.firestore().collection('customers').doc(userId).set({
            email,
            created: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log('Customer document created successfully for user:', userId);
        return { success: true };
    }
    catch (error) {
        console.error('Error creating customer:', error);
        throw new functions.https.HttpsError('internal', 'Failed to create customer record');
    }
});
//# sourceMappingURL=index.js.map