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
import { Briefcase, Star } from "lucide-react";

type JobPost = {
  id: string;
  title: string;
  company: string;
  location: string;
  posted_date: string;
  url?: string;
  salary?: string;
  job_type?: string;
};

interface SavedPostsTabProps {
  savedPosts: JobPost[];
  onUnsave: (id: string) => void;
  isLoading: boolean;
  error: string | null;
}

export default function SavedPostsTab({
  savedPosts,
  onUnsave,
  isLoading,
  error,
}: SavedPostsTabProps) {
  if (isLoading) {
    return (
      <div className="flex justify-center py-8">Loading saved posts...</div>
    );
  }

  if (error) {
    return <div className="text-red-500 py-8">Error: {error}</div>;
  }

  if (savedPosts.length === 0) {
    return (
      <div className="text-center py-8 text-muted-foreground">
        No saved job posts found. Save job posts by clicking the star icon.
      </div>
    );
  }

  const handleViewDetails = (url?: string) => {
    if (url) {
      window.open(url, "_blank");
    }
  };

  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3 mt-6">
      {savedPosts.map((job) => (
        <Card key={job.id}>
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle className="text-lg">{job.title}</CardTitle>
              <Briefcase className="h-5 w-5 text-muted-foreground" />
            </div>
            <CardDescription>{job.company}</CardDescription>
          </CardHeader>
          <CardContent>
            <p className="text-sm">Location: {job.location || "Not specified"}</p>
            {job.salary && (
              <p className="text-sm text-muted-foreground mt-2">
                Salary: {job.salary}
              </p>
            )}
            {job.job_type && (
              <p className="text-sm text-muted-foreground mt-1">
                Type: {job.job_type}
              </p>
            )}
            <p className="text-sm text-muted-foreground mt-2">
              Posted: {new Date(job.posted_date).toLocaleDateString()}
            </p>
          </CardContent>
          <CardFooter>
            <div className="flex w-full gap-2">
              <Button
                size="sm"
                className="flex-1"
                onClick={() => handleViewDetails(job.url)}
                disabled={!job.url}
              >
                {job.url ? "View Details" : "No Link"}
              </Button>
              <Button
                size="sm"
                variant="outline"
                onClick={() => onUnsave(job.id)}
                className="flex items-center gap-1"
              >
                <Star className="h-4 w-4 fill-yellow-400 text-yellow-400" />
                Unsave
              </Button>
            </div>
          </CardFooter>
        </Card>
      ))}
    </div>
  );
}
