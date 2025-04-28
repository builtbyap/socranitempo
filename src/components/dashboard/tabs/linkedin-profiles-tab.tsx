import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Linkedin } from "lucide-react";

export default function LinkedInProfilesTab() {
  // Sample data - in a real app, this would come from an API or database
  const linkedinProfiles = [
    {
      id: 1,
      name: "Alex Rodriguez",
      title: "Senior Product Manager",
      company: "Tech Innovations Inc.",
      connections: 500,
    },
    {
      id: 2,
      name: "Emily Watson",
      title: "Creative Director",
      company: "Creative Solutions",
      connections: 750,
    },
    {
      id: 3,
      name: "David Kim",
      title: "CTO",
      company: "Data Systems",
      connections: 1200,
    },
  ];

  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3 mt-6">
      {linkedinProfiles.map((profile) => (
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
            <p className="text-sm text-muted-foreground mt-2">
              {profile.connections}+ connections
            </p>
          </CardContent>
          <CardFooter>
            <Button size="sm" className="w-full">
              View Profile
            </Button>
          </CardFooter>
        </Card>
      ))}
    </div>
  );
}
