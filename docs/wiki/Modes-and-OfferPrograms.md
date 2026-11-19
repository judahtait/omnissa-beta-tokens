# Modes & OfferPrograms

Apple’s Beta dictionary in `com.apple.configuration.softwareupdate.settings`:

| Mode | Program enrollment | Require | Offer |
|---|---|---|---|
| Automatic | AlwaysOn | On (**one** program) | Off |
| Offer to user | Allowed | Off | On (**one or more**) |
| Offer, no sign-in | AlwaysOn | Off | On (**one or more**) |
| Block and unenroll | AlwaysOff | Off | Off |

## Require vs Offer

- **Require program** — single Description + Token. Device auto-enrolls.  
- **Offer programs** — array. Apple allows **multiple** Description + Token entries in **one** declaration. Keep them the **same OS** (all macOS or all iOS).

## UEM tips

- macOS tokens → Apple **macOS** profile; iOS → Apple **iOS** profile. Never mix.  
- Automatic pilots: one program per profile is clearest.  
- Offer pilots: you may list several same-OS seeds in one profile so users pick.  
- Do not use Allowed + Require together.

Apple: [Software Update settings](https://support.apple.com/guide/deployment/software-update-settings-declarative-dep0578d8b8a/web).
