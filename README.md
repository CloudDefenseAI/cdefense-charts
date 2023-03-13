# How to Install CloudDefense suite on a Kubernetes cluster

## Pre-requisites

There are three main pre-requisites for a production grade cdefense installation on-premises

1. A managed Postgres instance (for AWS RDS db.r5.large)
    1. enable automated backups
2. A kubernetes cluster (/examples/eks) with at least two nodegroups
    1. node group for jobs
        1. each node has { label: job }
    2. node group for all else
        1. (optional) each node has { label: cdefense }
3. A cluster auto-scaler

## WARNINGS

- Database URI has to be the Internal URI valid inside the private network
    - **DO NOT** obscure it behind a DNS as applications will be unable to connect to the database
- **DO NOT** change Database password or URI after helm install

