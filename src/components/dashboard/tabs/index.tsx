"use client";

import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import JobsPostsTab from "./jobs-posts-tab";
import EmailListTab from "./email-list-tab";
import LinkedInProfilesTab from "./linkedin-profiles-tab";

export default function DashboardTabs() {
  return (
    <Tabs defaultValue="jobs" className="w-full">
      <TabsList className="grid w-full grid-cols-3">
        <TabsTrigger value="jobs">Jobs Posts</TabsTrigger>
        <TabsTrigger value="email">Email List</TabsTrigger>
        <TabsTrigger value="linkedin">LinkedIn Profiles</TabsTrigger>
      </TabsList>
      <TabsContent value="jobs">
        <JobsPostsTab />
      </TabsContent>
      <TabsContent value="email">
        <EmailListTab />
      </TabsContent>
      <TabsContent value="linkedin">
        <LinkedInProfilesTab />
      </TabsContent>
    </Tabs>
  );
}
