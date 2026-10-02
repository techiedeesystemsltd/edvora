# Edvora tenancy architecture

## Core decision

Edvora uses **single-campus tenants**.

- One `schools` row = one Edvora tenant.
- A school cannot contain multiple campuses.
- There is no `campuses` table.
- There is no parent `organizations` table for schools.
- Every operational table contains `school_id`.
- A subscription belongs directly to one school.
- Billing is therefore one subscription per school/campus.

## Tenant boundary

```text
Edvora
├── School/Tenant A
│   ├── users/memberships
│   ├── students
│   ├── classes
│   ├── academics
│   ├── attendance
│   ├── CBT
│   ├── fees
│   ├── payments
│   ├── communication
│   ├── audit logs
│   └── subscription
│
├── School/Tenant B
│   └── completely independent data
│
└── School/Tenant C
    └── completely independent data
```

## Authentication

Supabase Auth owns user identity.

A user gets access to a school through `school_memberships`.

A user can technically belong to multiple independent schools, but each membership is isolated:

```text
user
 ├── membership → School A → owner
 └── membership → School B → teacher
```

This does **not** create a multi-campus school. These are separate Edvora tenants.

## Roles

School roles:

- owner
- admin
- bursar
- teacher
- staff

Platform administrators are stored separately in `platform_admins`. They are not school members.

## Authorization

Never trust a `school_id` supplied by the browser.

The database checks:

```text
auth.uid()
   ↓
school_memberships
   ↓
school_id
   ↓
RLS policy
```

For sensitive operations, use security-definer functions or server-side/Edge Function logic.

## Billing

`subscriptions.school_id` is unique.

That guarantees:

```text
School A → Subscription A
School B → Subscription B
School C → Subscription C
```

A subscription event also contains `school_id`.

Payment webhooks must resolve the provider subscription/customer to the Edvora school before changing subscription state.

## Storage

Use school-scoped paths:

```text
schools/{school_id}/branding/
schools/{school_id}/students/
schools/{school_id}/documents/
schools/{school_id}/reports/
schools/{school_id}/cbt/
```

Storage policies must verify membership against the path's school ID.

## Realtime

Realtime channels should also be tenant-scoped:

```text
school:{school_id}:announcements
school:{school_id}:attendance
school:{school_id}:payments
```

Never subscribe a browser to a global school-data channel.

## API / server architecture

```text
Next.js
   │
   ├── Public website
   ├── Auth
   ├── School dashboard
   └── Parent/student interfaces
          │
          ▼
     Supabase SSR
          │
          ▼
     PostgreSQL + RLS
          │
          ├── School A data
          ├── School B data
          └── School C data

Edge Functions
   ├── payment webhooks
   ├── transactional email
   ├── WhatsApp/SMS
   ├── AI operations
   └── scheduled jobs
```

## Billing webhook rule

A payment provider webhook must never blindly update a subscription using a browser-provided school ID.

Instead:

```text
Provider webhook
    ↓
Verify webhook signature
    ↓
Find provider subscription/customer
    ↓
Find Edvora subscription
    ↓
Get school_id
    ↓
Update ONLY that school
    ↓
Write subscription_events
    ↓
Audit log
```

## Data rules

Every new Edvora feature must answer:

1. Which school owns this record?
2. Is `school_id` present?
3. Does RLS enforce it?
4. Can a user from School A query School B's record?
5. Can a parent access only their linked student?
6. Can a teacher access only the classes they are assigned?
7. Can billing events update only the correct school?

If any answer is no, the feature is not production-ready.

## No multi-campus migration requirement

Because the product intentionally treats each campus as an independent tenant, there should be no school-group/campus abstraction in the MVP architecture.

If the same proprietor later operates several campuses, each campus creates/uses its own Edvora tenant and its own subscription.
