# Troubleshooting

| Symptom | Fix |
|---|---|
| 403 `APPLE_SEED_FOR_IT_TURNED_OFF` | Enroll org at [beta.apple.com/for-it](https://beta.apple.com/for-it) |
| Session 401/403 or expiry warning | New Apple Business service + new `.p7m` |
| Decrypt failed | Re-`init`, re-upload matching `.pem` |
| `--uem-block` errors | Narrow with `--os` / `--match` (exactly one hit) |
| Device not enrolling | Valid mode? Supervised? OS floor? Platform match? |
| 0 devices in Apple Business | Expected for the token-only service |
| Gatekeeper on download | Notarize + staple release, or right-click → Open until then |

More context: [Admin guide](../guide.md#6-troubleshooting).
