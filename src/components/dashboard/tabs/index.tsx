"use client";

import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import EmailListTab from "./email-list-tab";
import LinkedInProfilesTab from "./linkedin-profiles-tab";

export default function DashboardTabs() {
  return (
    <Tabs defaultValue="email" className="w-full">
      <TabsList className="grid w-full grid-cols-2">
        <TabsTrigger value="email">Email List</TabsTrigger>
        <TabsTrigger value="linkedin">LinkedIn Profiles</TabsTrigger>
      </TabsList>
      <TabsContent value="email">
        <EmailListTab />
      </TabsContent>
      <TabsContent value="linkedin">
        <LinkedInProfilesTab />
      </TabsContent>
    </Tabs>
  );
}
