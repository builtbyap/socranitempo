import { getFunctions, httpsCallable } from "firebase/functions";
import { app } from "./config";

const functions = getFunctions(app);

export const handleSuccessfulPayment = async ({ sessionId }: { sessionId: string }) => {
  const processPayment = httpsCallable(functions, 'handleSuccessfulPayment');
  try {
    const result = await processPayment({ sessionId });
    return result.data;
  } catch (error: any) {
    console.error("Error calling handleSuccessfulPayment:", error);
    throw new Error(error.message || "Failed to process payment");
  }
}; 