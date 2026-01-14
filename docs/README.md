# Documentation

This directory contains comprehensive technical documentation for the APIM Identity Delegation solution.

## Documents

### 📘 [Technical Solutions Documentation](./TECHNICAL_SOLUTIONS.md)
**Primary Reference** - Complete technical documentation covering:
- System architecture and components
- Technology stack details
- Authentication flows (with sequence diagrams)
- Infrastructure architecture (Bicep modules)
- Application components deep dive
- API endpoints reference
- Deployment procedures
- Security implementation
- Development guide
- Troubleshooting guide
- Best practices and recommendations

**Audience**: Developers, DevOps engineers, architects, and technical stakeholders

---

### 🏗️ [Architecture Overview](./ARCHITECTURE_OVERVIEW.md)
**Quick Reference** - High-level architectural overview including:
- System component diagrams
- Data flow diagrams
- Security layers
- Technology stack summary
- Resource dependencies
- Network flow
- Deployment pipeline
- Scalability and HA considerations
- Future enhancements

**Audience**: Architects, team leads, and stakeholders needing a quick overview

---

### 🚀 [Quick Start Guide](./QUICK_START.md)
**Getting Started** - Step-by-step setup instructions:
- Prerequisites checklist
- 5-minute local setup
- Full Azure deployment (30 minutes)
- Common commands reference
- Environment variables reference
- Troubleshooting quick fixes
- Quick reference card

**Audience**: New developers, operators, and anyone setting up the solution for the first time

---

## Documentation Structure

```
docs/
├── README.md                          # This file
├── TECHNICAL_SOLUTIONS.md             # Complete technical documentation
├── ARCHITECTURE_OVERVIEW.md           # High-level architecture guide
└── QUICK_START.md                     # Getting started guide
```

## How to Use This Documentation

### For New Team Members
1. Start with [Quick Start Guide](./QUICK_START.md) to get the system running
2. Read [Architecture Overview](./ARCHITECTURE_OVERVIEW.md) to understand the big picture
3. Dive into [Technical Solutions](./TECHNICAL_SOLUTIONS.md) for detailed implementation

### For Developers
1. Use [Quick Start Guide](./QUICK_START.md) for environment setup
2. Reference [Technical Solutions](./TECHNICAL_SOLUTIONS.md) for component details
3. Check troubleshooting sections when issues arise

### For Architects/Team Leads
1. Review [Architecture Overview](./ARCHITECTURE_OVERVIEW.md) for system design
2. Check [Technical Solutions](./TECHNICAL_SOLUTIONS.md) for security and best practices
3. Use for planning and decision-making

### For Operations/DevOps
1. Follow [Quick Start Guide](./QUICK_START.md) for deployment
2. Use [Technical Solutions](./TECHNICAL_SOLUTIONS.md) troubleshooting section
3. Reference monitoring and maintenance sections

## Key Topics Index

### Authentication & Security
- OAuth 2.0 / OIDC flow → [Technical Solutions](./TECHNICAL_SOLUTIONS.md#authentication-flow)
- HMAC signature verification → [Technical Solutions](./TECHNICAL_SOLUTIONS.md#delegation-request-verification)
- Managed Identity → [Technical Solutions](./TECHNICAL_SOLUTIONS.md#3-managed-identity)
- Security layers → [Architecture Overview](./ARCHITECTURE_OVERVIEW.md#security-layers)

### Infrastructure
- Bicep modules → [Technical Solutions](./TECHNICAL_SOLUTIONS.md#infrastructure-architecture)
- Resource dependencies → [Architecture Overview](./ARCHITECTURE_OVERVIEW.md#resource-dependencies)
- Deployment pipeline → [Architecture Overview](./ARCHITECTURE_OVERVIEW.md#deployment-pipeline)

### Application
- Component architecture → [Technical Solutions](./TECHNICAL_SOLUTIONS.md#application-components)
- API endpoints → [Technical Solutions](./TECHNICAL_SOLUTIONS.md#api-endpoints)
- Code structure → [Technical Solutions](./TECHNICAL_SOLUTIONS.md#project-structure)

### Operations
- Deployment steps → [Quick Start Guide](./QUICK_START.md#full-azure-deployment-30-minutes)
- Troubleshooting → [Technical Solutions](./TECHNICAL_SOLUTIONS.md#troubleshooting)
- Common commands → [Quick Start Guide](./QUICK_START.md#common-commands)
- Monitoring → [Architecture Overview](./ARCHITECTURE_OVERVIEW.md#monitoring--observability)

## Contributing to Documentation

When updating documentation:

1. **Keep it synchronized**: Update all affected documents when making changes
2. **Use clear language**: Write for clarity, avoid jargon when possible
3. **Include examples**: Code snippets, commands, and diagrams help understanding
4. **Test instructions**: Verify that setup/deployment steps work
5. **Update diagrams**: Keep architecture diagrams current with code changes

## Documentation Maintenance

### Review Schedule
- **Quarterly**: Review all documentation for accuracy
- **After major changes**: Update affected sections immediately
- **New features**: Document architecture and usage

### Version History

| Date | Version | Changes | Author |
|------|---------|---------|---------|
| 2026-01-14 | 1.0 | Initial comprehensive documentation | System |

## Feedback

If you find any issues with the documentation or have suggestions for improvement:
- Open an issue on GitHub
- Submit a pull request with corrections
- Contact the maintainers

## Additional Resources

### External Documentation
- [Azure API Management Documentation](https://learn.microsoft.com/en-us/azure/api-management/)
- [Auth0 Documentation](https://auth0.com/docs)
- [Go Documentation](https://go.dev/doc/)
- [Gin Framework](https://gin-gonic.com/docs/)
- [Azure Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)

### Related Topics
- [Azure Managed Identities](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)
- [OAuth 2.0 and OIDC](https://oauth.net/2/)
- [HMAC Authentication](https://en.wikipedia.org/wiki/HMAC)

## License

This documentation is part of the APIM Identity Delegation project. See [LICENSE](../LICENSE) for details.
