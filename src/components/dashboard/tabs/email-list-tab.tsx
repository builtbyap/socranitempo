"use client";

import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Mail, Loader2, Star, Search } from "lucide-react";
import { useEffect, useState } from "react";
import { createClient } from "../../../../supabase/client";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import SavedEmailsTab from "./saved-emails-tab";

interface EmailContact {
  id: string;
  name: string;
  email: string;
  company: string;
  lastContact: string;
}

export default function EmailListTab() {
  const [emailContacts, setEmailContacts] = useState<EmailContact[]>([]);
  const [savedEmails, setSavedEmails] = useState<EmailContact[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState("all");
  const [searchQuery, setSearchQuery] = useState("");

  useEffect(() => {
    const fetchEmails = async () => {
      try {
        setLoading(true);
        const supabase = createClient();

        const { data, error } = await supabase.from("emails").select("*");

        if (error) {
          throw new Error(error.message);
        }

        if (data) {
          // Remove duplicates by using a Map with email address as the key
          const uniqueEmails = new Map();
          data.forEach((email) => {
            if (!uniqueEmails.has(email.email)) {
              uniqueEmails.set(email.email, email);
            }
          });

          setEmailContacts(Array.from(uniqueEmails.values()));

          // Load saved emails from localStorage
          const savedEmailsIds = JSON.parse(
            localStorage.getItem("savedEmails") || "[]",
          );

          if (uniqueEmails.size > 0) {
            const savedItems = Array.from(uniqueEmails.values()).filter(
              (email) => savedEmailsIds.includes(email.id),
            );
            setSavedEmails(savedItems);
          }
        }
      } catch (err) {
        console.error("Error fetching emails:", err);
        setError(err instanceof Error ? err.message : "Failed to fetch emails");
      } finally {
        setLoading(false);
      }
    };

    fetchEmails();
  }, []);

  const handleSaveEmail = (email: EmailContact) => {
    // Add to saved emails if not already saved
    if (!savedEmails.some((savedEmail) => savedEmail.id === email.id)) {
      const updatedSavedEmails = [...savedEmails, email];
      setSavedEmails(updatedSavedEmails);

      // Save to localStorage
      const savedEmailsIds = updatedSavedEmails.map((email) => email.id);
      localStorage.setItem("savedEmails", JSON.stringify(savedEmailsIds));
    }
  };

  const handleUnsaveEmail = (id: string) => {
    // Remove from saved emails
    const updatedSavedEmails = savedEmails.filter((email) => email.id !== id);
    setSavedEmails(updatedSavedEmails);

    // Update localStorage
    const savedEmailsIds = updatedSavedEmails.map((email) => email.id);
    localStorage.setItem("savedEmails", JSON.stringify(savedEmailsIds));
  };

  const renderAllEmails = () => {
    if (loading) {
      return (
        <div className="flex justify-center items-center h-40">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
        </div>
      );
    }

    if (error) {
      return (
        <div className="bg-destructive/10 p-4 rounded-md text-destructive text-center">
          Error: {error}
        </div>
      );
    }

    if (emailContacts.length === 0) {
      return (
        <div className="text-center p-8 text-muted-foreground">
          No email contacts found.
        </div>
      );
    }

    return (
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {emailContacts.map((contact) => {
          const isSaved = savedEmails.some(
            (savedEmail) => savedEmail.id === contact.id,
          );

          return (
            <Card key={contact.id}>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <CardTitle className="text-lg">{contact.name}</CardTitle>
                  <Mail className="h-5 w-5 text-muted-foreground" />
                </div>
                <CardDescription>{contact.email}</CardDescription>
              </CardHeader>
              <CardContent>
                <p className="text-sm">Company: {contact.company}</p>
                <p className="text-sm text-muted-foreground mt-2">
                  Last contacted:{" "}
                  {new Date(contact.lastContact).toLocaleDateString()}
                </p>
              </CardContent>
              <CardFooter>
                <div className="flex w-full gap-2">
                  <Button size="sm" className="flex-1">
                    Send Email
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() =>
                      isSaved
                        ? handleUnsaveEmail(contact.id)
                        : handleSaveEmail(contact)
                    }
                    className="flex items-center gap-1"
                  >
                    <Star
                      className={`h-4 w-4 ${isSaved ? "fill-yellow-400 text-yellow-400" : ""}`}
                    />
                    {isSaved ? "Unsave" : "Save"}
                  </Button>
                </div>
              </CardFooter>
            </Card>
          );
        })}
      </div>
    );
  };

  return (
    <div className="flex flex-col md:flex-row gap-6 mt-6">
      <div className="flex-1">
        <Tabs
          defaultValue="all"
          className="w-full"
          onValueChange={setActiveTab}
        >
          <TabsList className="grid w-full grid-cols-2 mb-4">
            <TabsTrigger value="all">All Emails</TabsTrigger>
            <TabsTrigger value="saved">Saved Emails</TabsTrigger>
          </TabsList>

          {/* Search bar */}
          <div className="relative mb-4">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <input
              type="text"
              placeholder="Search emails by name, company, or email..."
              className="w-full pl-10 pr-4 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>

          <TabsContent value="all">{renderAllEmails()}</TabsContent>
          <TabsContent value="saved">
            <SavedEmailsTab
              savedEmails={savedEmails}
              onUnsave={handleUnsaveEmail}
              isLoading={loading}
              error={error}
            />
          </TabsContent>
        </Tabs>
      </div>
      <div className="md:w-64 space-y-4">
        <Card>
          <CardHeader>
            <CardTitle>Actions</CardTitle>
          </CardHeader>
          <CardContent>
            <Button
              className="w-full"
              onClick={() =>
                window.open(
                  "https://n8n.socrani.com/form/6272f3aa-a2f6-417a-9977-2b11ec3488a7",
                  "_blank",
                )
              }
            >
              Email Search
            </Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
