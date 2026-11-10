-- My Sign update 15: a member can switch between Learner and Tutor on the same account.
-- Run this once in Supabase → SQL Editor (after updates 1–14).

create or replace function public.switch_my_role(p_role text, p_accept_tax boolean default false)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_role not in ('learner', 'teacher') then
    raise exception 'Choose Learner or Tutor.';
  end if;
  if public.my_country() is null then
    raise exception 'Your account is suspended.';
  end if;
  if p_role = 'teacher' and not coalesce(p_accept_tax, false)
     and (select tax_terms_accepted_at from public.profiles where id = auth.uid()) is null then
    raise exception 'Accept the tax and legal responsibility to become a tutor.';
  end if;
  update public.profiles
     set role = p_role,
         tax_terms_accepted_at = case
           when p_role = 'teacher' and tax_terms_accepted_at is null then now()
           else tax_terms_accepted_at end
   where id = auth.uid();
end $$;

revoke execute on function public.switch_my_role(text, boolean) from public, anon;
grant execute on function public.switch_my_role(text, boolean) to authenticated;
