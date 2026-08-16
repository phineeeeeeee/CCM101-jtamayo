# Cloud Platform Recommendations

## Client Scenarios

### Client A — Startup Company
**Recommended Platform: AWS**
AWS is ideal for startups because it offers a generous Free Tier, transparent pay-as-you-go pricing, and auto-scaling services that match rapid growth without upfront cost. Its broad service menu lets you start small and expand seamlessly.
**Services**: Amazon EC2 (host app), Amazon S3 (store media), Amazon RDS (database).

### Client B — University (Microsoft Environment)
**Recommended Platform: Azure**
Since the university already uses Windows Server, Microsoft 365, and Active Directory, Azure integrates natively with zero new identity infrastructure. Licensing is often bundled, and hybrid tools extend existing investments smoothly.
**Services**: Azure Virtual Machines (migrate servers), Entra ID (unify identities), Azure SQL Database (migrate data).

### Client C — AI Research Company
**Recommended Platform: GCP**
GCP dominates AI/ML with Vertex AI, custom TPU accelerators, and BigQuery. It invented Kubernetes for scalable training and offers the most advanced research-grade tools.
**Services**: Vertex AI (ML pipelines), GKE (scale workloads), Cloud Storage (datasets).

### Client D — Global E-Commerce Company
**Recommended Platform: AWS**
AWS has the most regions, Availability Zones, and mature auto-scaling + global load balancing. It serves worldwide reliably with proven enterprise scale.
**Services**: EC2 Auto Scaling (handle traffic), S3 + CloudFront (global content), RDS Multi-AZ (highly available database).

---

## Multi-Cloud Decision Matrix

| Business Requirement | Recommended Platform | Justification |
|---|---|---|
| Startup Company | AWS | Free Tier, low entry cost, broad services, scaling |
| Enterprise Organization | Azure | Compliance, hybrid tools, enterprise agreements |
| Microsoft Environment | Azure | Native AD, 365, Windows integration |
| AI / Machine Learning | GCP | Vertex AI, TPUs, BigQuery, research leadership |
| Kubernetes Deployment | GCP | GKE originator, best support & open-source |
| Global Web Application | AWS | Most regions, AZs, proven reliability at scale |
