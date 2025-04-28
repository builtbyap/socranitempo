import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Mail } from "lucide-react";

export default function EmailListTab() {
  // Sample data - in a real app, this would come from an API or database
  const emailContacts = [
    {
      id: 1,
      name: "John Smith",
      email: "john.smith@example.com",
      company: "Tech Innovations Inc.",
      lastContact: "2023-06-10",
    },
    {
      id: 2,
      name: "Sarah Johnson",
      email: "sarah.j@creativesolutions.com",
      company: "Creative Solutions",
      lastContact: "2023-06-05",
    },
    {
      id: 3,
      name: "Michael Chen",
      email: "m.chen@datasystems.io",
      company: "Data Systems",
      lastContact: "2023-06-01",
    },
  ];

  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3 mt-6">
      {emailContacts.map((contact) => (
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
            <Button size="sm" className="w-full">
              Send Email
            </Button>
          </CardFooter>
        </Card>
      ))}
    </div>
  );
}
