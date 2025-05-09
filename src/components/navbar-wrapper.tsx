import { getUser } from "@/app/actions";
import Navbar from "./navbar";

export default async function NavbarWrapper() {
  const user = await getUser();
  return <Navbar user={user} />;
} 