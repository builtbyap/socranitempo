"use client";

import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import EmailListTab from "./email-list-tab";
import LinkedInProfilesTab from "./linkedin-profiles-tab";
import JobsPostsTab from "./jobs-posts-tab";

export default function DashboardTabs() {
  return (
    <Tabs defaultValue="email" className="w-full">
      <TabsList className="grid w-full grid-cols-3">
        <TabsTrigger value="email">Email List</TabsTrigger>
        <TabsTrigger value="linkedin">LinkedIn Profiles</TabsTrigger>
        <TabsTrigger value="jobs">Job Posts</TabsTrigger>
      </TabsList>
      <TabsContent value="email">
        <EmailListTab />
      </TabsContent>
      <TabsContent value="linkedin">
        <LinkedInProfilesTab />
      </TabsContent>
      <TabsContent value="jobs">
        <JobsPostsTab />
      </TabsContent>
    </Tabs>
  );
}
