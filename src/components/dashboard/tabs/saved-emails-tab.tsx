import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Mail, Star } from "lucide-react";

interface EmailContact {
  id: string;
  name: string;
  email: string;
  company: string;
  lastContact: string;
}

interface SavedEmailsTabProps {
  savedEmails: EmailContact[];
  onUnsave: (id: string) => void;
  isLoading: boolean;
  error: string | null;
}

export default function SavedEmailsTab({
  savedEmails,
  onUnsave,
  isLoading,
  error,
}: SavedEmailsTabProps) {
  if (isLoading) {
    return (
      <div className="flex justify-center py-8">Loading saved emails...</div>
    );
  }

  if (error) {
    return <div className="text-red-500 py-8">Error: {error}</div>;
  }

  if (savedEmails.length === 0) {
    return (
      <div className="text-center py-8 text-muted-foreground">
        No saved emails found. Save emails by clicking the star icon.
      </div>
    );
  }

  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3 mt-6">
      {savedEmails.map((contact) => (
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
                onClick={() => onUnsave(contact.id)}
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
