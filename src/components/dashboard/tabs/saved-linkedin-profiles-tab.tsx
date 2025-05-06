import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Linkedin, Star } from "lucide-react";

interface LinkedInProfile {
  id: string;
  name: string;
  title: string;
  company: string;
  connections: number;
  linkedin: string;
}

interface SavedLinkedInProfilesTabProps {
  savedProfiles: LinkedInProfile[];
  onUnsave: (id: string) => void;
  isLoading: boolean;
  error: string | null;
}

export default function SavedLinkedInProfilesTab({
  savedProfiles,
  onUnsave,
  isLoading,
  error,
}: SavedLinkedInProfilesTabProps) {
  if (isLoading) {
    return (
      <div className="flex justify-center py-8">Loading saved profiles...</div>
    );
  }

  if (error) {
    return <div className="text-red-500 py-8">Error: {error}</div>;
  }

  if (savedProfiles.length === 0) {
    return (
      <div className="text-center py-8 text-muted-foreground">
        No saved LinkedIn profiles found. Save profiles by clicking the star
        icon.
      </div>
    );
  }

  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3 mt-6">
      {savedProfiles.map((profile) => (
        <Card key={profile.id}>
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle className="text-lg">{profile.name}</CardTitle>
              <Linkedin className="h-5 w-5 text-muted-foreground" />
            </div>
            <CardDescription>{profile.title}</CardDescription>
          </CardHeader>
          <CardContent>
            <p className="text-sm">Company: {profile.company}</p>
          </CardContent>
          <CardFooter>
            <div className="flex w-full gap-2">
              <Button
                size="sm"
                className="flex-1"
                onClick={() => window.open(profile.linkedin, "_blank")}
              >
                View Profile
              </Button>
              <Button
                size="sm"
                variant="outline"
                onClick={() => onUnsave(profile.id)}
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
