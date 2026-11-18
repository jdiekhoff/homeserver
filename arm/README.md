# ARM (Automatic Ripping Machine)

Runs on the dedicated VM `pd-ripper-01` (192.168.4.219), deployed from `~/_src/homeserver/arm`.

## Storage

| Path on VM | In container | What |
| ---------- | ------------ | ---- |
| `/mnt/media/arm` (local disk `/dev/sdb1`) | `/home/arm`, db, logs, config, `media/raw`, `media/transcode` | Working space: keep local (ARM docs: fast disk; SQLite on NFS has locking issues) |
| `/mnt/review` (NFS) | `/home/arm/media/completed` | Finished rips land in TrueNAS `videos/review` |

`arm.yaml` keeps the default `COMPLETED_PATH: "/home/arm/media/completed/"`; the volume does the redirect.
ARM sorts output into `movies/`, `tv/`, `unidentified/` under review.

## NFS mount

TrueNAS export: `/mnt/Default/videos/review`, host 192.168.4.219 only, mapall to `jdiekhoff`
(ARM writes as uid 1002; mapall makes files owned like the rest of review).

`/etc/fstab` on the VM:

```
192.168.4.93:/mnt/Default/videos/review  /mnt/review  nfs4  hard,_netdev,nofail  0 0
```

Guard against Docker starting before the mount (ARM would silently write to local disk):
- `/mnt/review` is `chattr +i` while unmounted, so writes fail loudly instead.
- Docker drop-in `/etc/systemd/system/docker.service.d/wait-nfs.conf`: `[Unit]` `After=remote-fs.target`.

Notes:
- The move to completed is a network copy, so the final file appears in review while it's being written.
  Fine because Plex does not scan `review/`.
- If TrueNAS is down mid-copy, the ARM job blocks (hard mount) until it returns rather than corrupting the file.
