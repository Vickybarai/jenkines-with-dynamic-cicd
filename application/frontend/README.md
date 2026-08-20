# Frontend

React single-page application for the CDEC Alpha platform.

## Stack

| Tool | Version |
|------|---------|
| Node.js | 20.x (LTS) |
| npm | 10.x (bundled with Node 20) |
| React | 19 |
| TypeScript | 5.8 |
| Vite | 7 |
| Tailwind CSS | 4 |

## Prerequisites

Install Node.js 20 on your Linux machine:

```bash
node --version   # should print v20.x.x
npm --version
```

For S3 deployment, install and configure the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html):

```bash
aws --version
aws configure    # set access key, secret, and default region (e.g. eu-west-1)
```

## Setup

From the project root:

```bash
cd application/frontend
npm ci
```

Copy the example environment file and edit the API URLs if needed:

```bash
cp env.example .env
```

Environment variables (all prefixed with `VITE_` so Vite exposes them to the browser):

| Variable | Description |
|----------|-------------|
| `VITE_AUTH_API` | Auth service base URL |
| `VITE_COURSE_API` | Course service base URL |
| `VITE_ENROLL_API` | Enrollment service base URL |

## Run locally (development)

Start the dev server with hot reload:

```bash
npm run dev
```

Open [http://localhost:5173](http://localhost:5173) in your browser.

The dev server reads variables from `.env` (or `.env.local`).

## Build

### Development build

Use the dev server — no separate build step is required for day-to-day development:

```bash
npm run dev
```

### Production build

Set the API URLs for production, then build. Output is written to `dist/`.

```bash
export VITE_AUTH_API=https://api.thecloudnine.in/api/auth
export VITE_COURSE_API=https://api.thecloudnine.in/api/courses
export VITE_ENROLL_API=https://api.thecloudnine.in/api/enroll

npm run build
```

Or put those values in `.env` before running `npm run build`.

Preview the production build locally:

```bash
npm run preview
```

## Deploy to S3

After a production build, upload the contents of `dist/` to your S3 bucket.

Replace `YOUR-BUCKET-NAME` with your actual bucket name:

```bash
aws s3 sync dist/ s3://YOUR-BUCKET-NAME/ --delete
```

If the site is served through CloudFront, invalidate the cache so users get the new files:

```bash
aws cloudfront create-invalidation \
  --distribution-id YOUR-DISTRIBUTION-ID \
  --paths "/*"
```

Full deploy example:

```bash
cd application/frontend

export VITE_AUTH_API=https://api.thecloudnine.in/api/auth
export VITE_COURSE_API=https://api.thecloudnine.in/api/courses
export VITE_ENROLL_API=https://api.thecloudnine.in/api/enroll

npm ci
npm run build

aws s3 sync dist/ s3://YOUR-BUCKET-NAME/ --delete
aws cloudfront create-invalidation --distribution-id YOUR-DISTRIBUTION-ID --paths "/*"
```

## Other commands

```bash
npm run lint     # run ESLint
npm run preview  # serve the production build locally
```

## Project structure

```text
application/frontend/
├── src/              # React components and app code
├── public/           # Static assets copied as-is
├── dist/             # Production build output (created by npm run build)
├── env.example       # Example environment variables
├── package.json
└── vite.config.ts
```
