# pim-entra-role [![CI](https://github.com/CloudverveGmbH/terraform-azuread-pim-entra-role/actions/workflows/ci.yml/badge.svg)](https://github.com/CloudverveGmbH/terraform-azuread-pim-entra-role/actions/workflows/ci.yml)

A reusable Terraform module that implements just-in-time access to Microsoft Entra
directory roles (e.g. "Application Administrator") using Privileged Identity Management
(PIM) for Groups.

## Concept

The module creates two Entra ID security groups per directory role:

```
pim-<slug>-eligible   ← members are added here (normal group membership)
        │
        │  PIM eligibility schedule
        ▼
pim-<slug>            ← role-assignable group; holds the permanent directory role assignment
        │
        │  azuread_directory_role_assignment
        ▼
  Entra directory role (e.g. Application Administrator)
```

**Why two groups?**
The privileged group holds the directory role permanently, but its membership is
controlled by PIM. Only users who actively activate their eligibility appear in the
privileged group — and only for the configured time window. Adding or removing
people from the eligible group is a plain Entra group operation, no `terraform apply`
needed per joiner/leaver.

**Group naming** is derived automatically from `group_display_name`:
- `"Application Admin"` → groups `pim-application-admin` and `pim-application-admin-eligible`

**Approver type inference:** passing an `object_id` without a `type` field causes the
module to look up the Entra directory object and set `groupMembers` for groups or
`singleUser` for users automatically.

**Difference to `pim-azure-role`:** this module targets _Entra directory roles_ (tenant-wide,
no Azure resource scope), whereas `pim-azure-role` targets _Azure RBAC roles_ on
resources, resource groups, subscriptions, or management groups.

## Requirements

| Requirement | Details |
|---|---|
| Terraform | >= 1.9 |
| hashicorp/azuread | >= 3.0 |
| hashicorp/time | >= 0.10 |
| Entra licence | Microsoft Entra ID P2 or Entra ID Governance |
| Terraform principal permissions | `Privileged Role Administrator` or `Global Administrator` (required to create role-assignable groups and assign directory roles) |

### Microsoft Graph API permissions (Application, not Delegated)

The Terraform SPN requires the following **Application** permissions on the Microsoft Graph API:

| Permission | Reason |
|---|---|
| `Application.ReadWrite.OwnedBy` | Update owned app registrations (e.g. adding group owners) |
| `Group.Create` | Create the Eligible and Privileged security groups |
| `Group.Read.All` | Read existing groups to detect duplicates and resolve members |
| `RoleManagement.ReadWrite.Directory` | Manage PIM eligibility schedules, role management policies, and directory role assignments |
| `User.ReadBasic.All` | Resolve user objects for approver type inference |

## Usage

### Minimal – self-activation, justification always required

```hcl
module "app_admin_pim" {
  source  = "CloudverveGmbH/pim-entra-role/azuread"
  version = "~> 0.1"

  group_display_name      = "Application Admin"
  entra_role_display_name = "Application Administrator"

  members = [
    { object_id = data.azuread_user.alice.object_id, display_name = "Alice" },
  ]
}
```

### With approval by a specific user

```hcl
module "privileged_role_admin_pim" {
  source  = "CloudverveGmbH/pim-entra-role/azuread"
  version = "~> 0.1"

  group_display_name          = "Privileged Role Admin"
  entra_role_display_name     = "Privileged Role Administrator"
  maximum_activation_duration = "PT2H"

  members = [
    { object_id = data.azuread_user.bob.object_id, display_name = "Bob" },
  ]

  # type is inferred automatically – no need to specify "singleUser"
  approvers = [
    { object_id = data.azuread_user.alice.object_id },
  ]
}
```

### With approval by a group

```hcl
approvers = [
  { object_id = azuread_group.security_team.object_id }  # type "groupMembers" inferred automatically
]
```

### Manage eligible group membership outside Terraform

Leave `members = []` (the default) and add users directly to the
`pim-<slug>-eligible` group in the Entra admin center. This avoids a
`terraform apply` every time the team changes.

```hcl
module "app_admin_pim" {
  source  = "CloudverveGmbH/pim-entra-role/azuread"
  version = "~> 0.1"
  group_display_name      = "Application Admin"
  entra_role_display_name = "Application Administrator"
  # members = []  ← default; manage via Entra admin center
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `group_display_name` | `string` | derived from role name | Optional override for the group base name. When omitted, the slug is derived from `entra_role_display_name` automatically |
| `entra_role_display_name` | `string` | — | Display name of the Entra directory role to assign (e.g. `"Application Administrator"`) |
| `group_owners` | `list(string)` | `[]` | Additional owner object IDs (Terraform SPN is always added) |
| `members` | `list(object)` | `[]` | Initial members of the Eligible group (`object_id`, optional `display_name`) |
| `approvers` | `list(object)` | `[]` | PIM approvers (`object_id`, optional `type`); when set, approval is required on activation |
| `require_justification` | `bool` | `true` | Require a business justification on activation (independent of approval) |
| `maximum_activation_duration` | `string` | `"PT4H"` | ISO 8601 duration; shorter windows recommended for high-privilege directory roles |
| `eligibility_years` | `number` | `1` | Validity of the eligibility schedule in years |

## Outputs

| Name | Description |
|---|---|
| `eligible_group_id` | Object ID of the Eligible group |
| `eligible_group_name` | Display name of the Eligible group (`pim-<slug>-eligible`) |
| `privileged_group_id` | Object ID of the Privileged group (role-assignable) |
| `privileged_group_name` | Display name of the Privileged group (`pim-<slug>`) |
| `group_id` | Alias for `privileged_group_id` (backward-compatible) |
| `principal_id` | Alias for `privileged_group_id` |
| `resolved_approvers` | Approvers with their resolved PIM type after auto-inference |
| `directory_role_assignment_id` | Resource ID of the Entra directory role assignment |

---

# pim-entra-role (Deutsch)

Wiederverwendbares Terraform-Modul für Just-in-Time-Zugriff auf Microsoft-Entra-Verzeichnisrollen
(z. B. „Application Administrator") mit Privileged Identity Management (PIM) for Groups.

## Konzept

Das Modul erstellt pro Verzeichnisrolle zwei Entra-ID-Sicherheitsgruppen:

```
pim-<slug>-eligible   ← Mitglieder werden hier eingetragen (normale Gruppenmitgliedschaft)
        │
        │  PIM-Eligibility-Schedule
        ▼
pim-<slug>            ← rollenberechtigte Gruppe; hält die dauerhafte Verzeichnisrollenzuweisung
        │
        │  azuread_directory_role_assignment
        ▼
  Entra-Verzeichnisrolle (z. B. Application Administrator)
```

**Warum zwei Gruppen?**
Die privilegierte Gruppe hält die Verzeichnisrolle dauerhaft, ihre Mitgliedschaft
wird aber durch PIM gesteuert. Nur User, die ihre Eligibility aktiv aktiviert haben,
erscheinen in der privilegierten Gruppe — und nur für das konfigurierte Zeitfenster.
Personen in der Eligible-Gruppe hinzuzufügen oder zu entfernen ist eine einfache
Entra-Gruppenoperation, kein `terraform apply` pro Neueinsteiger oder Ausscheider.

**Gruppennamensgebung** wird automatisch aus `group_display_name` abgeleitet:
- `"Application Admin"` → Gruppen `pim-application-admin` und `pim-application-admin-eligible`

**Approver-Typ-Inferenz:** Wird ein `object_id` ohne `type` übergeben, schaut das Modul
das Entra-Directory-Objekt nach und setzt automatisch `groupMembers` für Gruppen bzw.
`singleUser` für Einzelpersonen.

**Unterschied zu `pim-azure-role`:** Dieses Modul zielt auf _Entra-Verzeichnisrollen_
(mandantenweit, kein Azure-Ressourcen-Scope), während `pim-azure-role` auf
_Azure-RBAC-Rollen_ auf Ressourcen, Ressourcengruppen, Subscriptions oder
Management Groups abzielt.

## Voraussetzungen

| Anforderung | Details |
|---|---|
| Terraform | >= 1.9 |
| hashicorp/azuread | >= 3.0 |
| hashicorp/time | >= 0.10 |
| Entra-Lizenz | Microsoft Entra ID P2 oder Entra ID Governance |
| Terraform-Principal-Rechte | `Privileged Role Administrator` oder `Global Administrator` (erforderlich zum Erstellen rollenberechtigter Gruppen und Zuweisen von Verzeichnisrollen) |

### Microsoft Graph API-Berechtigungen (Application, nicht Delegated)

Der Terraform-SPN benötigt folgende **Application**-Berechtigungen auf der Microsoft Graph API:

| Berechtigung | Grund |
|---|---|
| `Application.ReadWrite.OwnedBy` | Eigene App-Registrierungen aktualisieren (z. B. Gruppenbesitzer hinzufügen) |
| `Group.Create` | Eligible- und Privileged-Sicherheitsgruppen erstellen |
| `Group.Read.All` | Vorhandene Gruppen lesen (Duplikaterkennung, Member-Auflösung) |
| `RoleManagement.ReadWrite.Directory` | PIM-Eligibility-Schedules, Rollenmanagement-Richtlinien und Verzeichnisrollenzuweisungen verwalten |
| `User.ReadBasic.All` | User-Objekte für die automatische Approver-Typ-Erkennung auflösen |

## Verwendung

### Minimal – Selbstaktivierung, Begründung immer erforderlich

```hcl
module "app_admin_pim" {
  source  = "CloudverveGmbH/pim-entra-role/azuread"
  version = "~> 0.1"

  group_display_name      = "Application Admin"
  entra_role_display_name = "Application Administrator"

  members = [
    { object_id = data.azuread_user.alice.object_id, display_name = "Alice" },
  ]
}
```

### Mit Genehmigung durch eine Person

```hcl
approvers = [
  { object_id = data.azuread_user.alice.object_id }  # Typ wird automatisch als "singleUser" erkannt
]
```

### Mit Genehmigung durch eine Gruppe

```hcl
approvers = [
  { object_id = azuread_group.security_team.object_id }  # Typ wird automatisch als "groupMembers" erkannt
]
```

### Gruppenmitgliedschaft außerhalb von Terraform verwalten

`members = []` (Standard) lassen und User direkt im Entra Admin Center zur
`pim-<slug>-eligible`-Gruppe hinzufügen. Vermeidet `terraform apply` bei
jeder Teamänderung.

## Eingabevariablen

| Name | Typ | Standard | Beschreibung |
|---|---|---|---|
| `group_display_name` | `string` | aus Rollenname abgeleitet | Optionaler Override für den Gruppenbasisnamen. Wenn weggelassen, wird der Slug automatisch aus `entra_role_display_name` abgeleitet |
| `entra_role_display_name` | `string` | — | Anzeigename der Entra-Verzeichnisrolle (z. B. `"Application Administrator"`) |
| `group_owners` | `list(string)` | `[]` | Zusätzliche Owner-Object-IDs (Terraform-SPN wird immer ergänzt) |
| `members` | `list(object)` | `[]` | Initiale Mitglieder der Eligible-Gruppe (`object_id`, optionaler `display_name`) |
| `approvers` | `list(object)` | `[]` | PIM-Genehmiger (`object_id`, optionaler `type`); wenn gesetzt, ist Genehmigung bei Aktivierung Pflicht |
| `require_justification` | `bool` | `true` | Begründung bei Aktivierung erforderlich (unabhängig von Genehmigung) |
| `maximum_activation_duration` | `string` | `"PT4H"` | ISO-8601-Dauer; kürzere Fenster für hochprivilegierte Verzeichnisrollen empfohlen |
| `eligibility_years` | `number` | `1` | Gültigkeit des Eligibility-Schedules in Jahren |

## Ausgaben

| Name | Beschreibung |
|---|---|
| `eligible_group_id` | Object-ID der Eligible-Gruppe |
| `eligible_group_name` | Anzeigename der Eligible-Gruppe (`pim-<slug>-eligible`) |
| `privileged_group_id` | Object-ID der Privileged-Gruppe (rollenberechtigend) |
| `privileged_group_name` | Anzeigename der Privileged-Gruppe (`pim-<slug>`) |
| `group_id` | Alias für `privileged_group_id` (abwärtskompatibel) |
| `principal_id` | Alias für `privileged_group_id` |
| `resolved_approvers` | Genehmiger mit aufgelöstem PIM-Typ nach Auto-Inferenz |
| `directory_role_assignment_id` | Ressourcen-ID der Entra-Verzeichnisrollenzuweisung |

## Beitragen

Siehe [CONTRIBUTING.md](CONTRIBUTING.md) für den PR-, Changelog- und Release-Prozess.