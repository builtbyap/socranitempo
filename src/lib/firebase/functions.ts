import { getFunctions, httpsCallable } from "firebase/functions";
import { app } from "./config";

const functions = getFunctions(app);

interface PaymentResult {
  success: boolean;
  subscription?: {
    customerId: string;
    subscriptionId: string;
    priceId: string;
    productId: string;
    tier: string;
    status: string;
    currentPeriodEnd: number;
  };
}

export const handleSuccessfulPayment = async ({ sessionId }: { sessionId: string }): Promise<PaymentResult> => {
  const processPayment = httpsCallable<{ sessionId: string }, PaymentResult>(functions, 'handleSuccessfulPayment');
  try {
    const result = await processPayment({ sessionId });
    return result.data;
  } catch (error: any) {
    console.error("Error calling handleSuccessfulPayment:", error);
    throw new Error(error.message || "Failed to process payment");
  }
}; 