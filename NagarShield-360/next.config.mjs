/** @type {import('next').NextConfig} */
const nextConfig = {
  outputFileTracingIncludes: {
    '/api/demo-footage': ['./Video/Facebook.mp4'],
  },
}

export default nextConfig
