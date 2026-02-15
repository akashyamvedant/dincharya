/** @type {import('next').NextConfig} */
const nextConfig = {
  // Skip ESLint during builds (flat config can cause Vercel build issues)
  eslint: {
    ignoreDuringBuilds: true,
  },
  // Prevent source maps in production for security
  productionBrowserSourceMaps: false,
  // Security headers
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
          { key: 'X-XSS-Protection', value: '1; mode=block' },
        ],
      },
    ];
  },
};

export default nextConfig;
