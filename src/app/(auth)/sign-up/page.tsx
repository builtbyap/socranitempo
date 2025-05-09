import { Message } from "@/components/form-message";
import { SmtpMessage } from "../smtp-message";
import Navbar from "@/components/navbar";
import { UrlProvider } from "@/components/url-provider";
import { SignUpForm } from "@/components/sign-up-form";

export default async function Signup(props: {
  searchParams: Promise<Message>;
}) {
  const searchParams = await props.searchParams;
  if ("message" in searchParams) {
    return (
      <div className="flex h-screen w-full flex-1 items-center justify-center p-4 sm:max-w-md">
        <SignUpForm message={searchParams} />
      </div>
    );
  }

  return (
    <>
      <Navbar user={null} />
      <div className="flex min-h-screen flex-col items-center justify-center bg-background px-4 py-8">
        <div className="w-full max-w-md rounded-lg border border-border bg-card p-6 shadow-sm">
          <UrlProvider>
            <SignUpForm />
          </UrlProvider>
        </div>
        <SmtpMessage />
      </div>
    </>
  );
}
