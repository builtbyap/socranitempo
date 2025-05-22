import Link from 'next/link';

const Footer = () => {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="bg-gray-50 border-t border-gray-100">
      <div className="container mx-auto px-4 py-8 flex flex-col md:flex-row justify-between items-center">
        <div className="text-gray-600 mb-4 md:mb-0">
          © {currentYear} Your Company. All rights reserved.
        </div>
        <div className="flex gap-6">
          <Link href="/terms" className="text-gray-600 hover:text-blue-600">Terms &amp; Conditions</Link>
          <Link href="/privacy" className="text-gray-600 hover:text-blue-600">Privacy Policy</Link>
        </div>
      </div>
    </footer>
  );
}

export default Footer;
