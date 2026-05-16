# PetMagic - Authentication & User Management Platform

A production-ready modular monolith with ASP.NET Core backend and Next.js admin panel for user and role management.

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose (v2.0+)
- Git

### One-Command Local Startup

`ash
# Clone repository and navigate to root
git clone <repo>
cd petmagic-0_004

# Copy environment template
cp .env.example .env

# Start all services (PostgreSQL + API + Admin Web)
docker-compose up --build
`

#### Expected Output:
- PostgreSQL: Ready at localhost:5432
- Backend API: Ready at http://localhost:5000 (health check: /health)
- Admin Web: Ready at http://localhost:3000

#### Default Credentials:
- Email: dmin@petmagic.app
- Password: DemoPassword123!

---

## 📋 Architecture

### Services

| Service | Port | Role | Tech Stack |
|---------|------|------|------------|
| **PostgreSQL 16** | 5432 | Persistent data store | Alpine image, volume backup |
| **Backend API** | 5000 | REST API, JWT auth, business logic | .NET 10, EF Core 10, Serilog, OpenTelemetry |
| **Admin Web** | 3000 | Admin dashboard for user management | Next.js 16, TypeScript, RU/EN localization |

### Project Structure

`
petmagic-0_004/
├── docker-compose.yml          # Orchestration definition
├── Dockerfile.api              # Backend multi-stage build
├── apps/admin-web/
│   └── Dockerfile              # Frontend build
├── src/
│   ├── Host/                   # Application entry point
│   ├── Modules/Identity/       # Authentication module (DDD vertical slice)
│   │   ├── Domain/             # Business entities
│   │   ├── Application/        # Use cases, contracts, validation
│   │   ├── Infrastructure/     # Data access, external services
│   │   └── Api/                # HTTP endpoints
│   └── BuildingBlocks/         # Cross-cutting concerns (Result, Error)
└── tests/                      # Unit tests (XUnit)
`

---

## 🔧 Configuration

### Environment Variables (.env)

`nv
# Database
POSTGRES_PASSWORD=YourStrongPassword

# JWT Signing
JWT_SIGNING_KEY=Base64EncodedKey  # Generate: openssl rand -base64 64

# Bootstrap Admin
BOOTSTRAP_ADMIN_EMAIL=admin@petmagic.app
BOOTSTRAP_ADMIN_PASSWORD=YourPassword123!

# Frontend API Endpoint
NEXT_PUBLIC_API_BASE_URL=http://localhost:5000

# Optional: OAuth
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
`

### Customization

- **Backend config**: src/Host/PetMagic.Host.Api/appsettings.json
- **Database**: Connection string in docker-compose.yml or .env
- **Frontend themes**: pps/admin-web/app/globals.css

---

## 🏗️ Development Workflow

### Local Build & Test (No Docker)

`ash
# Navigate to project root
cd d:\Flutter\project\petmagic-0_004

# Restore NuGet packages
dotnet restore

# Build solution
dotnet build PetMagic.slnx

# Run unit tests
dotnet test PetMagic.slnx

# Run backend API (requires PostgreSQL on localhost:5432)
cd src/Host/PetMagic.Host.Api
dotnet run

# In another terminal, run frontend dev server
cd apps/admin-web
npm install
npm run dev
`

---

## 📚 API Documentation

### Authentication Endpoints

| Method | Endpoint | Auth | Purpose |
|--------|----------|------|---------|
| POST | /api/auth/register | None | Register new mobile user (Flutter iOS/Android) |
| POST | /api/auth/login | None | Login with email/password |
| POST | /api/auth/refresh | None | Refresh expired access token |
| POST | /api/auth/logout | Bearer | Invalidate own refresh token |
| GET | /api/auth/me | Bearer | Get current user profile |
| GET | /api/auth/external/{provider} | None | OAuth login initiation |

Admin Web policy: login-only for Admin/Moderator users. Self-registration is intentionally disabled in admin-web UI.

### Economy Endpoints (PawSpark)

| Method | Endpoint | Auth | Purpose |
|--------|----------|------|---------|
| GET | /api/economy/wallet | Bearer | Get current user PawSpark balance and reward counters |
| POST | /api/economy/wallet/claim-weekly | Bearer | Claim weekly PawSpark grant (Free/Premium) |
| POST | /api/economy/wallet/claim-ad | Bearer | Claim rewarded-ad PawSpark (daily capped) |
| POST | /api/economy/wallet/spend | Bearer | Spend PawSpark for generation actions |
| GET | /api/economy/packs | None | List available PawSpark packs (USD/EUR) |
| POST | /api/economy/purchases/create | Bearer | Create pack purchase order and receive checkout link |
| GET | /api/economy/purchases/{orderId} | Bearer | Get user-owned purchase status |
| POST | /api/economy/purchases/{orderId}/confirm | Bearer | Confirm purchase and credit PawSpark (manual fallback) |
| POST | /api/economy/webhooks/stripe | None | Stripe webhook endpoint with signature verification and idempotency |

Economy defaults for MVP: Free weekly grant 100 PS, Premium weekly grant 250 PS, rewarded ads limit 5/day.
Stripe checkout and webhook settings:
- `Economy:StripeSecretKey`
- `Economy:StripeWebhookSecret`
- `Economy:StripeCheckoutSuccessUrl`
- `Economy:StripeCheckoutCancelUrl`

Webhook endpoint expects `Stripe-Signature` header and uses Stripe SDK signature verification.

### Admin Endpoints (requires Admin/Moderator role)

| Method | Endpoint | Auth | Purpose |
|--------|----------|------|---------|
| GET | /api/admin/users | ModeratorOrAdmin | List all users |
| PUT | /api/admin/users/{id}/role | AdminOnly | Assign role to user |
| DELETE | /api/admin/users/{id}/role | AdminOnly | Revoke role from user |
| PUT | /api/admin/users/{id}/premium | ModeratorOrAdmin | Toggle premium status |
| PATCH | /api/admin/users/{id}/active | ModeratorOrAdmin | Activate/deactivate user |

---

## 🔐 Security

### Features
✅ JWT with refresh token rotation (30 min access, 30 day refresh by default)
✅ Refresh token session tracking with revocation
✅ Password hashing with PBKDF2
✅ Role-based access control (Admin, Moderator, User)
✅ Context isolation + no remote module in Electron (if applicable)
✅ CORS configured for admin-web origin
✅ Serilog audit logging with correlation IDs

### Known Issues & Mitigations
See [SECURITY.md](./SECURITY.md) for dependency vulnerability audit and suppression rationale.

---

## 🧪 Testing

`ash
# Run all unit tests
dotnet test PetMagic.slnx

# Run specific test class
dotnet test PetMagic.slnx --filter RegisterUserCommandValidatorTests

# Run with coverage (requires coverlet)
dotnet test PetMagic.slnx /p:CollectCoverage=true
`

---

## 📦 Deployment

### Docker Compose (Development)
`ash
docker-compose up --build
`

### Production Checklist
- [ ] Update .env with strong, unique credentials
- [ ] Enable HTTPS (nginx reverse proxy recommended)
- [ ] Configure external PostgreSQL (e.g., AWS RDS)
- [ ] Set up OpenTelemetry exporter to Grafana/Jaeger
- [ ] Enable API rate limiting
- [ ] Configure secrets vault (Vault, AWS Secrets Manager)
- [ ] Run security scanning on Docker images (Trivy)
- [ ] Set up CI/CD pipeline with automated tests

---

## 📝 Documentation

- **Architecture**: Modular Monolith with Vertical Slices (DDD)
- **API Design**: RESTful with JWT Bearer authentication
- **Frontend**: Next.js App Router with dynamic localization ([locale] segments)
- **Database**: PostgreSQL 16 with EF Core 10 migrations
- **Observability**: Serilog (structured logging) + OpenTelemetry (distributed tracing)

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| Container won't start | Check docker logs <container_name> |
| DB connection error | Verify POSTGRES_PASSWORD in .env matches docker-compose |
| API returns 500 | Check backend logs: docker logs petmagic_api |
| Admin Web blank page | Check browser console + frontend logs:
pm run dev |
| CORS errors | Verify NEXT_PUBLIC_API_BASE_URL matches docker-compose backend service name |

---

## 📄 License

[Your License Here]

## 👥 Contributors

- PetMagic Development Team

---

## 📞 Support

For issues or questions:
1. Check [SECURITY.md](./SECURITY.md) for known vulnerabilities
2. Review API documentation above
3. Check container logs: \docker-compose logs\
4. Open an issue on GitHub
