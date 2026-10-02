# V22 school creation → dashboard trace

1. `/onboarding` collects the exact school name.
2. `/api/onboarding/school` validates it and calls `create_school_v22`.
3. `create_school_v22` inserts a new `schools` row and an `owner` membership for `auth.uid()`, then returns the new UUID.
4. The API returns `/dashboard?school=<new UUID>` and the browser stores that UUID as `edvora.currentSchoolId`.
5. Dashboard and shared school context first resolve that selected UUID against the authenticated user’s active membership. If none is selected, they use the newest active membership rather than an arbitrary/old membership.
6. All school-scoped queries continue to use the resolved `schoolId`, so the displayed name and tenant data come from the same school record.

## Important database check
If an existing account still opens the old school, inspect its memberships in Supabase:

```sql
select sm.user_id, sm.school_id, sm.role, sm.status, sm.created_at, s.name, s.slug
from public.school_memberships sm
join public.schools s on s.id = sm.school_id
where sm.user_id = auth.uid()
order by sm.created_at desc;
```

The application no longer chooses an older membership simply because it happens to be first.
