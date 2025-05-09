"use client";

import { useEffect, useState } from "react";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Linkedin, Search, Star } from "lucide-react";
import { createClient } from "../../../../supabase/client";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import SavedLinkedInProfilesTab from "./saved-linkedin-profiles-tab";

interface LinkedInProfile {
  id: string;
  name: string;
  title: string;
  company: string;
  connections: number;
  linkedin: string;
}

export default function LinkedInProfilesTab() {
  const [profiles, setProfiles] = useState<LinkedInProfile[]>([]);
  const [savedProfiles, setSavedProfiles] = useState<LinkedInProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState("all");
  const [searchQuery, setSearchQuery] = useState("");

  const supabase = createClient();

  useEffect(() => {
    async function fetchProfiles() {
      try {
        setLoading(true);
        const { data, error } = await supabase.from("profiles").select("*");

        if (error) {
          throw new Error(error.message);
        }

        // Log the raw data to help with debugging
        console.log("Raw profiles data:", data);

        // Filter out profiles with missing required fields, but with more lenient checks
        const validProfiles = (data || []).filter(
          (profile) => profile && profile.id,
        );

        setProfiles(validProfiles);

        // Load saved profiles from localStorage
        const savedProfilesIds = JSON.parse(
          localStorage.getItem("savedLinkedInProfiles") || "[]",
        );

        if (validProfiles.length > 0) {
          const savedItems = validProfiles.filter((profile) =>
            savedProfilesIds.includes(profile.id),
          );
          setSavedProfiles(savedItems);
        }
      } catch (err) {
        console.error("Error fetching LinkedIn profiles:", err);
        setError(
          err instanceof Error ? err.message : "Failed to fetch profiles",
        );
      } finally {
        setLoading(false);
      }
    }

    fetchProfiles();
  }, []);

  const handleSaveProfile = (profile: LinkedInProfile) => {
    // Add to saved profiles if not already saved
    if (!savedProfiles.some((savedProfile) => savedProfile.id === profile.id)) {
      const updatedSavedProfiles = [...savedProfiles, profile];
      setSavedProfiles(updatedSavedProfiles);

      // Save to localStorage
      const savedProfilesIds = updatedSavedProfiles.map(
        (profile) => profile.id,
      );
      localStorage.setItem(
        "savedLinkedInProfiles",
        JSON.stringify(savedProfilesIds),
      );
    }
  };

  const handleUnsaveProfile = (id: string) => {
    // Remove from saved profiles
    const updatedSavedProfiles = savedProfiles.filter(
      (profile) => profile.id !== id,
    );
    setSavedProfiles(updatedSavedProfiles);

    // Update localStorage
    const savedProfilesIds = updatedSavedProfiles.map((profile) => profile.id);
    localStorage.setItem(
      "savedLinkedInProfiles",
      JSON.stringify(savedProfilesIds),
    );
  };

  const handleViewProfile = (linkedinUrl: string) => {
    // Open LinkedIn profile in a new tab
    window.open(linkedinUrl, "_blank");
  };

  const renderAllProfiles = () => {
    if (loading) {
      return (
        <div className="flex justify-center items-center h-40">
          <p>Loading profiles...</p>
        </div>
      );
    }

    if (error) {
      return (
        <div className="flex justify-center items-center h-40 text-red-500">
          <p>Error: {error}</p>
        </div>
      );
    }

    if (profiles.length === 0) {
      return (
        <div className="flex justify-center items-center h-40">
          <p>No LinkedIn profiles found.</p>
        </div>
      );
    }

    return (
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3 mt-6">
        {profiles.map((profile) => {
          const isSaved = savedProfiles.some(
            (savedProfile) => savedProfile.id === profile.id,
          );

          // Parse name to separate the part before and after the dash
          const fullName = profile.name || "No Name";
          let displayName = fullName;
          let titleFromName = "";

          if (fullName.includes(" - ")) {
            const parts = fullName.split(" - ");
            displayName = parts[0];
            titleFromName = parts.slice(1).join(" - ");
          }

          // Use the title from name or fall back to the original title
          const displayTitle = titleFromName || profile.title || "No Title";

          return (
            <Card key={profile.id}>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <CardTitle className="text-lg">{displayName}</CardTitle>
                  <Linkedin className="h-5 w-5 text-muted-foreground" />
                </div>
                <CardDescription>{displayTitle}</CardDescription>
              </CardHeader>
              <CardContent>
                <p className="text-sm">
                  Company: {profile.company || "No Company"}
                </p>
              </CardContent>
              <CardFooter>
                <div className="flex w-full gap-2">
                  <Button
                    size="sm"
                    className="flex-1"
                    onClick={() => handleViewProfile(profile.linkedin || "#")}
                  >
                    {profile.linkedin ? "View Profile" : "No Profile Link"}
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() =>
                      isSaved
                        ? handleUnsaveProfile(profile.id)
                        : handleSaveProfile(profile)
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
    <div className="flex flex-col md:flex-row gap-6">
      <div className="flex-1">
        <Tabs
          defaultValue="all"
          className="w-full"
          onValueChange={setActiveTab}
        >
          <TabsList className="grid w-full grid-cols-2 mb-4">
            <TabsTrigger value="all">All Profiles</TabsTrigger>
            <TabsTrigger value="saved">Saved Profiles</TabsTrigger>
          </TabsList>

          {/* Search bar */}
          <div className="relative mb-4">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <input
              type="text"
              placeholder="Search profiles by name, title, or company..."
              className="w-full pl-10 pr-4 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>

          <TabsContent value="all">{renderAllProfiles()}</TabsContent>
          <TabsContent value="saved">
            <SavedLinkedInProfilesTab
              savedProfiles={savedProfiles}
              onUnsave={handleUnsaveProfile}
              isLoading={loading}
              error={error}
            />
          </TabsContent>
        </Tabs>
      </div>
      <div className="w-full md:w-64 mt-6 flex flex-col gap-4">
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Actions</CardTitle>
          </CardHeader>
          <CardContent>
            <Button
              className="w-full"
              onClick={() =>
                window.open(
                  "https://n8n.socrani.com/form/c85d7ad6-0b7b-436d-aad6-ee849404d145",
                  "_blank",
                )
              }
            >
              LinkedIn Search
            </Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
