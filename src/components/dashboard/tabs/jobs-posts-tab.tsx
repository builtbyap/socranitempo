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
import { Briefcase, Search, Star } from "lucide-react";
import { useEffect, useState } from "react";
import { createClient } from "../../../../supabase/client";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import SavedPostsTab from "./saved-posts-tab";
import { toast } from "@/components/ui/use-toast";

type JobPost = {
  id: string;
  title: string;
  company: string;
  location: string;
  posted_date: string;
  application?: string;
};

export default function JobsPostsTab() {
  const [jobPosts, setJobPosts] = useState<JobPost[]>([]);
  const [savedPosts, setSavedPosts] = useState<JobPost[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState("all");
  const [searchQuery, setSearchQuery] = useState("");

  // Function to check if a URL is valid and accessible
  const checkUrlValidity = async (url: string): Promise<boolean> => {
    if (!url) return false;

    try {
      // Use a simple HEAD request to check if the URL is accessible
      const response = await fetch(url, {
        method: "HEAD",
        mode: "no-cors", // This is needed for cross-origin requests
        cache: "no-cache",
      });

      // Since we're using no-cors, we can't actually check the status
      // But if the fetch doesn't throw an error, we'll assume it's valid
      return true;
    } catch (error) {
      console.error(`Error checking URL ${url}:`, error);
      return false;
    }
  };

  useEffect(() => {
    const fetchJobPosts = async () => {
      try {
        setIsLoading(true);
        const supabase = createClient();
        const { data, error } = await supabase.from("socrani").select("*");

        if (error) {
          throw new Error(error.message);
        }

        if (data && data.length > 0) {
          // Filter out posts with invalid application URLs
          const validatedPosts = [];
          let invalidCount = 0;

          for (const post of data) {
            // If there's no application URL, keep the post
            if (!post.application) {
              validatedPosts.push(post);
              continue;
            }

            // Check if the URL is valid
            const isValid = await checkUrlValidity(post.application);
            if (isValid) {
              validatedPosts.push(post);
            } else {
              invalidCount++;
            }
          }

          setJobPosts(validatedPosts);

          if (invalidCount > 0) {
            toast({
              title: "Some job posts were filtered out",
              description: `${invalidCount} job posts with invalid application URLs were removed.`,
              duration: 5000,
            });
          }

          // Load saved posts from localStorage
          const savedPostsIds = JSON.parse(
            localStorage.getItem("savedJobPosts") || "[]",
          );

          const savedItems = validatedPosts.filter((post) =>
            savedPostsIds.includes(post.id),
          );
          setSavedPosts(savedItems);
        } else {
          setJobPosts([]);
        }
      } catch (err) {
        console.error("Error fetching job posts:", err);
        setError(
          err instanceof Error ? err.message : "Failed to fetch job posts",
        );
      } finally {
        setIsLoading(false);
      }
    };

    fetchJobPosts();
  }, []);

  const handleSavePost = (post: JobPost) => {
    // Add to saved posts if not already saved
    if (!savedPosts.some((savedPost) => savedPost.id === post.id)) {
      const updatedSavedPosts = [...savedPosts, post];
      setSavedPosts(updatedSavedPosts);

      // Save to localStorage
      const savedPostsIds = updatedSavedPosts.map((post) => post.id);
      localStorage.setItem("savedJobPosts", JSON.stringify(savedPostsIds));
    }
  };

  const handleUnsavePost = (id: string) => {
    // Remove from saved posts
    const updatedSavedPosts = savedPosts.filter((post) => post.id !== id);
    setSavedPosts(updatedSavedPosts);

    // Update localStorage
    const savedPostsIds = updatedSavedPosts.map((post) => post.id);
    localStorage.setItem("savedJobPosts", JSON.stringify(savedPostsIds));
  };

  const renderAllPosts = () => {
    if (isLoading) {
      return (
        <div className="flex justify-center py-8">Loading job posts...</div>
      );
    }

    if (error) {
      return <div className="text-red-500 py-8">Error: {error}</div>;
    }

    if (jobPosts.length === 0) {
      return <div className="py-8">No job posts found.</div>;
    }

    return (
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3 mt-6">
        {jobPosts.map((job) => {
          const isSaved = savedPosts.some(
            (savedPost) => savedPost.id === job.id,
          );

          return (
            <Card key={job.id}>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <CardTitle className="text-lg">{job.title}</CardTitle>
                  <Briefcase className="h-5 w-5 text-muted-foreground" />
                </div>
                <CardDescription>{job.company}</CardDescription>
              </CardHeader>
              <CardContent>
                <p className="text-sm">Location: {job.location}</p>
                <p className="text-sm text-muted-foreground mt-2">
                  Posted on: {new Date(job.posted_date).toLocaleDateString()}
                </p>
              </CardContent>
              <CardFooter>
                <div className="flex w-full gap-2">
                  <Button
                    size="sm"
                    className="flex-1"
                    onClick={() =>
                      job.application && window.open(job.application, "_blank")
                    }
                  >
                    View Details
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() =>
                      isSaved ? handleUnsavePost(job.id) : handleSavePost(job)
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
            <TabsTrigger value="all">All Posts</TabsTrigger>
            <TabsTrigger value="saved">Saved Posts</TabsTrigger>
          </TabsList>

          {/* Search bar */}
          <div className="relative mb-4">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <input
              type="text"
              placeholder="Search jobs by title, company, or location..."
              className="w-full pl-10 pr-4 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>

          <TabsContent value="all">{renderAllPosts()}</TabsContent>
          <TabsContent value="saved">
            <SavedPostsTab
              savedPosts={savedPosts}
              onUnsave={handleUnsavePost}
              isLoading={isLoading}
              error={error}
            />
          </TabsContent>
        </Tabs>
      </div>

      {/* Right sidebar with Search For Jobs button */}
      <div className="w-full md:w-64 flex flex-col gap-4">
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Job Search</CardTitle>
            <CardDescription>Find new opportunities</CardDescription>
          </CardHeader>
          <CardContent>
            <Button
              className="w-full"
              onClick={() =>
                window.open(
                  "https://n8n.socrani.com/form/40f50911-103d-4269-a139-4edc220007e5",
                  "_blank",
                )
              }
            >
              Search For Jobs
            </Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
