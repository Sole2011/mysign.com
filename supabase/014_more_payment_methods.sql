-- My Sign update 14: payment methods for other countries
-- (Venmo, PayPal, Zelle, Cash App, mobile money) besides the Ethiopian ones.
-- Run this once in Supabase → SQL Editor (after updates 1–13).

alter table public.lesson_requests drop constraint lesson_requests_payment_method_check;
alter table public.lesson_requests add constraint lesson_requests_payment_method_check
  check (payment_method in ('telebirr', 'cbe_birr', 'mpesa', 'venmo', 'paypal', 'zelle', 'cashapp', 'mobile_money', 'bank', 'cash', 'other'));

create or replace function public.submit_payment_proof(
  p_request_id uuid, p_method text, p_reference text, p_proof_path text
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.my_country() is null then
    raise exception 'Your account is suspended.';
  end if;
  if p_method not in ('telebirr', 'cbe_birr', 'mpesa', 'venmo', 'paypal', 'zelle', 'cashapp', 'mobile_money', 'bank', 'cash', 'other') then
    raise exception 'Choose how you paid.';
  end if;
  if p_proof_path is not null and p_proof_path not like auth.uid()::text || '/%' then
    raise exception 'Invalid receipt.';
  end if;
  update public.lesson_requests
     set payment_method = p_method,
         payment_reference = left(coalesce(trim(p_reference), ''), 100),
         payment_proof_path = p_proof_path,
         payment_submitted_at = now()
   where id = p_request_id and learner_id = auth.uid() and status = 'accepted' and paid_at is null;
  if not found then
    raise exception 'This lesson is not waiting for payment.';
  end if;
end $$;

create or replace function public.record_payment(p_request_id uuid, p_method text, p_reference text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.my_country() is null then
    raise exception 'Your account is suspended.';
  end if;
  if p_method is not null and p_method not in ('telebirr', 'cbe_birr', 'mpesa', 'venmo', 'paypal', 'zelle', 'cashapp', 'mobile_money', 'bank', 'cash', 'other') then
    raise exception 'Choose how you were paid.';
  end if;
  update public.lesson_requests
     set paid_at = now(),
         payment_later = false,
         payment_method = coalesce(p_method, payment_method),
         payment_reference = case when coalesce(trim(p_reference), '') <> ''
                                  then left(trim(p_reference), 100) else payment_reference end
   where id = p_request_id and teacher_id = auth.uid() and status = 'accepted' and paid_at is null;
  if not found then
    raise exception 'This lesson is not waiting for payment, or it is already paid.';
  end if;
end $$;
