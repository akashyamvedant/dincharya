'use client';

import './globals.css';
import Sidebar from '@/components/Sidebar';
import GlobalSearch from '@/components/GlobalSearch';
import { ToastProvider } from '@/components/Toast';
import { usePathname } from 'next/navigation';
import { useState, useCallback } from 'react';

export default function RootLayout({ children }) {
  const pathname = usePathname();
  const isLoginPage = pathname === '/login';
  const [searchOpen, setSearchOpen] = useState(false);

  const handleSearchToggle = useCallback((action) => {
    if (action === 'toggle') setSearchOpen(prev => !prev);
    else setSearchOpen(false);
  }, []);

  return (
    <html lang="en">
      <head>
        <title>DinCharya Admin</title>
        <meta name="description" content="DinCharya Admin Dashboard" />
      </head>
      <body>
        <ToastProvider>
          {isLoginPage ? (
            children
          ) : (
            <div className="app-layout">
              <Sidebar onSearchOpen={() => setSearchOpen(true)} />
              <main className="main-content">{children}</main>
              <GlobalSearch isOpen={searchOpen} onClose={handleSearchToggle} />
            </div>
          )}
        </ToastProvider>
      </body>
    </html>
  );
}
