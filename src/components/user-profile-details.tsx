"use client";

import { User } from "@supabase/supabase-js";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "./ui/dialog";
import { Button } from "./ui/button";
import { UserCircle } from "lucide-react";

interface UserProfileDetailsProps {
  user: User;
}

export default function UserProfileDetails({ user }: UserProfileDetailsProps) {
  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button variant="ghost" className="w-full justify-start">
          View Profile Details
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <UserCircle className="h-5 w-5" />
            User Profile
          </DialogTitle>
        </DialogHeader>
        <div className="bg-muted/50 rounded-lg p-4 overflow-hidden">
          <pre className="text-xs font-mono max-h-48 overflow-auto">
            {JSON.stringify(user, null, 2)}
          </pre>
        </div>
      </DialogContent>
    </Dialog>
  );
}
