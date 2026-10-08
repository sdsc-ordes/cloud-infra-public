# Notes

This has been deployed by hand with the helm CLI. Eventually it will need to be
migrated to a proper gitops-based deployment, with dev on one cluster, and prod
on another cluster (each in the same `hackagon` ns). This means the running
instances **including prod** will need to be migrated without losing the data on
it.

## Migration

> [!IMPORTANT]
>
> Do not uninstall / delete the helm release until the new one is up and
> running.

### Checklist

- is the storageClass Retain (i.e. are the PersistentVolumes deleted when the
  PVC is deleted?).
  - No it is `Delete`! CAREFUL
- is there an external backup?

### Process

1. Close all connections to the running instance database.

- Standard way: scale hackagon `frontend` and `backend` replicas to 0 (Hopefully
  that does not delete volumes). VERIFY

2. Export all data: use pg_dump

```bash
kubectl exec -n <old-ns> <old-db-pod> -- \
  pg_dumpall -U postgres > ~/postgresql-backup-$(date +%Y%m%d-%H%M%S).sql
```

#### With CNPG

It is now recommended to use the cloudnative postgres (cnpg) operator to deploy
postgres on k8s. There is a special mode to bootstrap a cnpg db from an existing
db. See:
https://christianhuth.de/migrating-a-bitnami-postgresql-helm-release-to-cloudnativepg/

Always use more than 1 replicas for prod db (I think 3, check docs).

#### Without CNPG

3. Restore the data in the newly setup gitops instance.

```bash
# Get the superuser password
  PGPASSWORD=$(kubectl get secret -n postgresql postgresql-pg-superuser \
-o jsonpath='{.data.password}' | base64 -d)

  # Restore
  cat ~/postgresql-backup-*.sql | \
    kubectl exec -i -n <new-ns> <new-db-pod> -- \
    env PGPASSWORD=$PGPASSWORD psql -U postgres
```

> [!NOTE]
>
> The hackagon pg instance containst multiple databases in one instance. When
> using cnpg import, don't forget to specify `type: monolith`.

4. Verify success

```bash
# List databases
kubectl exec -n postgresql postgresql-pg-1 -- psql -U postgres -c '\l'
```

### After migration

Configure backups to the cluster.
https://cloudnative-pg.io/documentation/1.20/backup#retention-policies
