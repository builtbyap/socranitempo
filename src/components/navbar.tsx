"use client";

import Link from "next/link";
import { Button } from "./ui/button";
import { User, UserCircle } from "lucide-react";
import UserProfile from "./user-profile";
import { useUser } from "@/hooks/use-user";

export default function Navbar() {
  const { user } = useUser();

  return (
    <nav className="w-full border-b border-gray-200 bg-white py-2">
      <div className="container mx-auto px-4 flex justify-between items-center">
        <Link href="/" prefetch className="text-xl font-bold">
          Socrani
        </Link>
        <div className="flex gap-4 items-center">
          <Link
            href="/features"
            className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
          >
            Features
          </Link>
          {user ? (
            <>
              <Link href="/dashboard">
                <Button variant="default" className="font-medium">
                  Dashboard
                </Button>
              </Link>
              <UserProfile />
            </>
          ) : (
            <>
              <Link
                href="/sign-in"
                className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
              >
                Sign In
              </Link>
              <Link
                href="/sign-up"
                className="px-4 py-2 text-sm font-medium text-white bg-black rounded-md hover:bg-gray-800"
              >
                Sign Up
              </Link>
            </>
          )}
        </div>
      </div>
    </nav>
  );
}
