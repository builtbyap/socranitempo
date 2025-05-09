'use client'
import { UserCircle } from 'lucide-react'
import { Button } from './ui/button'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger } from './ui/dropdown-menu'
import { createClient } from '../../supabase/client'
import { useRouter } from 'next/navigation'
import { useState } from 'react'
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle, AlertDialogTrigger } from './ui/alert-dialog'

export default function UserProfile() {
    const supabase = createClient()
    const router = useRouter()
    const [isCancelling, setIsCancelling] = useState(false)

    const handleCancelSubscription = async () => {
        try {
            setIsCancelling(true)
            // TODO: Implement subscription cancellation logic
            // This could be a call to your backend API or Stripe
            await new Promise(resolve => setTimeout(resolve, 1000)) // Simulated delay
            router.refresh()
        } catch (error) {
            console.error('Error cancelling subscription:', error)
        } finally {
            setIsCancelling(false)
        }
    }

    return (
        <DropdownMenu>
            <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="icon">
                    <UserCircle className="h-6 w-6" />
                </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
                <DropdownMenuItem onClick={async () => {
                    await supabase.auth.signOut()
                    router.refresh()
                }}>
                    Sign out
                </DropdownMenuItem>
                <DropdownMenuSeparator />
                <AlertDialog>
                    <AlertDialogTrigger asChild>
                        <DropdownMenuItem
                            className="text-red-600 focus:text-red-600 focus:bg-red-50"
                            onSelect={(e: Event) => e.preventDefault()}
                        >
                            Cancel Subscription
                        </DropdownMenuItem>
                    </AlertDialogTrigger>
                    <AlertDialogContent>
                        <AlertDialogHeader>
                            <AlertDialogTitle>Cancel Subscription</AlertDialogTitle>
                            <AlertDialogDescription>
                                Are you sure you want to cancel your subscription? You'll lose access to premium features at the end of your current billing period.
                            </AlertDialogDescription>
                        </AlertDialogHeader>
                        <AlertDialogFooter>
                            <AlertDialogCancel>Keep Subscription</AlertDialogCancel>
                            <AlertDialogAction
                                onClick={handleCancelSubscription}
                                className="bg-red-600 hover:bg-red-700 focus:ring-red-600"
                                disabled={isCancelling}
                            >
                                {isCancelling ? 'Cancelling...' : 'Yes, Cancel Subscription'}
                            </AlertDialogAction>
                        </AlertDialogFooter>
                    </AlertDialogContent>
                </AlertDialog>
            </DropdownMenuContent>
        </DropdownMenu>
    )
}