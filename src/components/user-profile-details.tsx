"use client";

import type { User } from "@supabase/supabase-js";
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
    <div className="space-y-4">
      <div>
        <h3 className="text-lg font-medium">Email</h3>
        <p className="text-sm text-muted-foreground">{user.email}</p>
      </div>
      <div>
        <h3 className="text-lg font-medium">User ID</h3>
        <p className="text-sm text-muted-foreground">{user.id}</p>
      </div>
      <div>
        <h3 className="text-lg font-medium">Email Verified</h3>
        <p className="text-sm text-muted-foreground">
          {user.email_confirmed_at ? "Yes" : "No"}
        </p>
      </div>
    </div>
  );
}
