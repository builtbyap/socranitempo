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
import { Briefcase, Loader2, Star, Search } from "lucide-react";
import { useEffect, useState } from "react";
import { createClient } from "../../../../supabase/client";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import SavedPostsTab from "./saved-posts-tab";

interface JobPost {
  id: string;
  title: string;
  company: string;
  location: string;
  posted_date: string;
  description?: string;
  url?: string;
  salary?: string;
  job_type?: string;
}

export default function JobsPostsTab() {
  const [jobPosts, setJobPosts] = useState<JobPost[]>([]);
  const [savedPosts, setSavedPosts] = useState<JobPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState("all");
  const [searchQuery, setSearchQuery] = useState("");

  useEffect(() => {
    const fetchJobPosts = async () => {
      try {
        setLoading(true);
        const supabase = createClient();

        const { data, error } = await supabase.from("job_posts").select("*").order("posted_date", { ascending: false });

        if (error) {
          throw new Error(error.message);
        }

        if (data) {
          setJobPosts(data);

          // Load saved posts from localStorage
          const savedPostsIds = JSON.parse(
            localStorage.getItem("savedJobPosts") || "[]",
          );

          if (data.length > 0) {
            const savedItems = data.filter((post) =>
              savedPostsIds.includes(post.id),
            );
            setSavedPosts(savedItems);
          }
        }
      } catch (err) {
        console.error("Error fetching job posts:", err);
        setError(
          err instanceof Error ? err.message : "Failed to fetch job posts",
        );
      } finally {
        setLoading(false);
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

  const handleViewDetails = (url?: string) => {
    if (url) {
      window.open(url, "_blank");
    }
  };

  const filteredPosts = jobPosts.filter((post) => {
    if (!searchQuery) return true;
    const query = searchQuery.toLowerCase();
    return (
      post.title.toLowerCase().includes(query) ||
      post.company.toLowerCase().includes(query) ||
      post.location?.toLowerCase().includes(query) ||
      post.description?.toLowerCase().includes(query)
    );
  });

  const renderAllPosts = () => {
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

    if (filteredPosts.length === 0) {
      return (
        <div className="text-center p-8 text-muted-foreground">
          {searchQuery
            ? "No job posts found matching your search."
            : "No job posts found."}
        </div>
      );
    }

    return (
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {filteredPosts.map((post) => {
          const isSaved = savedPosts.some(
            (savedPost) => savedPost.id === post.id,
          );

          return (
            <Card key={post.id}>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <CardTitle className="text-lg">{post.title}</CardTitle>
                  <Briefcase className="h-5 w-5 text-muted-foreground" />
                </div>
                <CardDescription>{post.company}</CardDescription>
              </CardHeader>
              <CardContent>
                <p className="text-sm">Location: {post.location || "Not specified"}</p>
                {post.salary && (
                  <p className="text-sm text-muted-foreground mt-2">
                    Salary: {post.salary}
                  </p>
                )}
                {post.job_type && (
                  <p className="text-sm text-muted-foreground mt-1">
                    Type: {post.job_type}
                  </p>
                )}
                <p className="text-sm text-muted-foreground mt-2">
                  Posted: {new Date(post.posted_date).toLocaleDateString()}
                </p>
              </CardContent>
              <CardFooter>
                <div className="flex w-full gap-2">
                  <Button
                    size="sm"
                    className="flex-1"
                    onClick={() => handleViewDetails(post.url)}
                    disabled={!post.url}
                  >
                    {post.url ? "View Details" : "No Link"}
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() =>
                      isSaved ? handleUnsavePost(post.id) : handleSavePost(post)
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
            <TabsTrigger value="all">All Jobs</TabsTrigger>
            <TabsTrigger value="saved">Saved Jobs</TabsTrigger>
          </TabsList>

          {/* Search bar */}
          <div className="relative mb-4">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <input
              type="text"
              placeholder="Search jobs by title, company, location, or description..."
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
                  "https://n8n.socrani.com/form/job-search-form",
                  "_blank",
                )
              }
            >
              Job Search
            </Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
