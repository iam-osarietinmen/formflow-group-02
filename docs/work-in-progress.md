# Phase 0: Design Worksheet

Before writing a single line of code, we sat down and worked through the design decisions. This was probably the most important part of the entire project because, as the brief said, "a system that happens to work is not the same as a system that was designed."

## 1.1 Tier Boundaries

| Tier     | Technology          | Container Name      | Purpose                                                                                             |
| -------- | ------------------- | ------------------- | --------------------------------------------------------------------------------------------------- |
| Frontend | NetJS               | `formflow-frontend` | Serves the user interface (UI), manages client-side routing, and sends API requests to the backend. |
| Backend  | Node.js/Express     | `formflow-backend`  | Processes form submissions, executes business logic, and communicates with the database.            |
| Database | PostgreSQL + Prisma | `formflow-db`       | Stores form data, user information, and application state persistently.                             |

**Why Each Is Separate:**

**1. Frontend Container:** The frontend is a static web application that only needs a web server (like Nginx) to serve files. It doesn't need to know anything about the database or business logic—it just makes HTTP requests to the backend API. Keeping it separate means we can update the UI without touching the backend logic.

**2. Backend Container:** The backend contains all the business logic, validation rules, and API endpoints. It needs to connect to the database but doesn't care about how the UI is rendered. By isolating it, we can scale the backend independently if traffic increases, and we can update API logic without redeploying the frontend.

**3. Database Container:** The database stores all persistent data. It has different resource requirements (more disk I/O, more memory for caching) and a different update cadence than the application code. Keeping it separate means we can use a persistent volume for data and back up the database independently.

**Why Not Combine Them?**

If we combined everything into one container, we would lose the ability to:

- Update one component without rebuilding the entire application

- Scale components independently

- Use different base images optimized for each tier

- Isolate failures (a crash in the backend shouldn't take down the database)

> **Design Reflection:** This separation follows the single responsibility principle and makes the system more maintainable. We considered using a multi-stage build for the frontend to keep the image small, which I'll implement in the Dockerfile.\*

## 1.2 Versioning and Tagging Strategy

**Our Design Decision:**

We will use a combination of semantic versioning and Git commit SHA for image tagging.

**Tagging Format:**

```text
<image-name>:<version>-<short-sha>
```

```
formflow-frontend:1.0.3-a1b2c3d
formflow-backend:1.0.3-a1b2c3d
```

```
formflow-frontend:1.0.3
formflow-frontend:1.0
formflow-frontend:1
```

**How I'll Know Which Version Is Running in Production:**

1. The deployment script will record the deployed image tag in a `deployed-version.txt` file on the VM

2. The GitHub Actions workflow will log which tag was deployed

3. We can SSH into the VM and run docker ps to see exactly which image is running

4. Each container will have a VERSION environment variable set to the tag

**Rollback Procedure (Step by Step):**

1. Identify the issue: Monitor the application or receive an alert

2. Check current version: SSH into VM and run `docker ps --format "table {{.Image}}\t{{.Names}}"` to see what's running

3. List available versions: Check Docker Hub for previous tags or look at the `deployed-versions.log` file

4. Select rollback target: Choose the last known-good version (e.g., `1.0.2-a1b2c3d`)

5. Update docker-compose.yml: Change the image tag to the rollback version

6. Recreate containers: Run docker compose down && docker compose up -d

7. Verify: Check that the application is working correctly

8. Document: Record the rollback in the incident log

**Why This Strategy:**

- Semantic versioning gives me a human-readable way to understand what changed

- The SHA provides an exact link to the Git commit that produced the image

- Multiple tags (1.0.3, 1.0, 1) give flexibility — we can pin to a specific patch or just the major version

- This approach eliminates the need for the latest tag in production

> Design Reflection: We specifically avoided using latest in production because it's impossible to know what version "latest" actually refers to at any given moment. This was one of the key failures the client experienced before

## 1.3 Secrets Handling Plan

**Secrets Required:**

| **Secret**                  | **Purpose**                 | **Where It Lives**                          |
| --------------------------- | --------------------------- | ------------------------------------------- |
| `DB_PASSWORD`               | Database password           | Injected as environment variable at runtime |
| `DB_USER`                   | Database username           | Injected as environment variable at runtime |
| `DB_NAME`                   | Database name               | Injected as environment variable at runtime |
| `JWT_SECRET`                | JWT signing key             | Injected as environment variable at runtime |
| `API_KEY` _(if applicable)_ | External API authentication | Injected as environment variable at runtime |
| `DOCKERHUB_USERNAME`        | Docker Hub username         | Injected as environment variable at runtime |
| `DOCKERHUB_TOKEN`           | Docker Hub access token     | Injected as environment variable at runtime |
| `VM_HOST`                   | Deployment VM address       | Injected as environment variable at runtime |
| `VM_USERNAME`               | Deployment VM username      | Injected as environment variable at runtime |
| `VM_SSH_KEY`                | SSH private key             | Injected as environment variable at runtime |

**How Secrets Will Be Managed:**

1. Never hardcoded: No secrets will appear in Dockerfiles, docker-compose.yml, or any committed file

2. GitHub Secrets: All secrets will be stored in the GitHub repository's Secrets settings

3. Environment variables: Secrets will be passed to containers via environment variables in the docker-compose.yml on the VM

4. .env file on VM: The VM will have a .env file (not committed to Git) that the deployment script will create from GitHub Secrets

5. No build-time secrets: We won't use secrets during the build process—only at runtime

**Security Measures:**

- The `.env` file on the VM will have restricted permissions (600)

- We'll use docker compose secrets where possible

- We'll regularly rotate secrets and update them in GitHub Secrets

> Design Reflection: We considered using Docker Secrets (the Swarm feature), but since I'm deploying to a single VM without Swarm, environment variables from a secured .env file are the most practical approach
