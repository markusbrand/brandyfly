## MODIFIED Requirements

### Requirement: Production container validation
The backend production image SHALL build for Linux AMD64 and Linux ARM64 and
SHALL run as a non-root user with a health endpoint.

#### Scenario: ARM64 image is inspected
- **WHEN** continuous validation builds the production backend image for Linux ARM64
- **THEN** the image build succeeds and its configured runtime user is not root

#### Scenario: AMD64 image is inspected
- **WHEN** continuous validation builds the production backend image for Linux AMD64
- **THEN** the image build succeeds and its configured runtime user is not root

## ADDED Requirements

### Requirement: Automated backend deployment
Every push to `main` SHALL publish the multi-arch backend image and deploy it to
the backend server through a self-hosted runner whose labels match that
server's operating system and CPU architecture. The deployment SHALL fail
unless the backend health endpoint answers successfully on the server within
30 seconds after the service is restarted.

#### Scenario: Successful deployment
- **WHEN** a commit is pushed to `main` and the deployment server's runner is online
- **THEN** the server pulls the published image matching its architecture, restarts the service, and the deploy job succeeds only after `/healthz` returns success

#### Scenario: Unhealthy deployment
- **WHEN** the restarted service does not answer `/healthz` successfully within 30 seconds
- **THEN** the deploy job fails and prints the recent service logs

#### Scenario: Server migration
- **WHEN** the backend moves to a server with a different CPU architecture or operating system
- **THEN** the documented migration checklist identifies the runner labels, image platforms, and tunnel route that must be updated
