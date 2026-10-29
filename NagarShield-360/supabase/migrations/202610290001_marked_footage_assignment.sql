-- Attach an officer-marked JPEG to a task in the same transaction that assigns it.
-- The source clip stays private and the assignee can read only the related evidence.
create or replace function public.assign_marked_demo_task(
  p_incident uuid,
  p_department text,
  p_team text,
  p_assignee uuid,
  p_note text,
  p_media_key text
) returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_task uuid;
begin
  if auth.uid() is null or public.my_role() not in ('executive','department_head') then
    raise exception 'কর্মকর্তার অনুমতি প্রয়োজন';
  end if;
  if length(trim(coalesce(p_note,''))) < 8 or length(p_note) > 1000 then
    raise exception 'কাজের বিবরণ ঠিক করুন';
  end if;
  if p_media_key !~ ('^task/' || auth.uid()::text || '/[0-9a-f-]{36}\.jpg$') then
    raise exception 'স্ক্রিনশটের পথ ঠিক নয়';
  end if;
  if not exists (
    select 1 from storage.objects
    where bucket_id='evidence' and name=p_media_key
  ) then
    raise exception 'চিহ্নিত স্ক্রিনশট পাওয়া যায়নি';
  end if;

  v_task := public.perform_demo_action('assign_task', p_incident,
    jsonb_build_object('department_id', p_department, 'team_id', p_team,
      'assignee_id', p_assignee, 'note', p_note));
  insert into public.media_assets(incident_id, task_id, owner_uid, storage_key, mime_type, stage)
  values(p_incident, v_task, auth.uid(), p_media_key, 'image/jpeg', 'before');
  return v_task;
end $$;
revoke all on function public.assign_marked_demo_task(uuid,text,text,uuid,text,text) from public,anon;
grant execute on function public.assign_marked_demo_task(uuid,text,text,uuid,text,text) to authenticated;

create or replace function public.marked_footage_ready() returns boolean
language sql stable set search_path=public as $$ select true $$;
revoke all on function public.marked_footage_ready() from public,anon;
grant execute on function public.marked_footage_ready() to authenticated;

-- Allow cleanup when assignment validation fails after the officer uploads a frame.
create policy evidence_delete_own_unlinked on storage.objects for delete to authenticated using (
  bucket_id='evidence' and (storage.foldername(name))[1]='task' and
  (storage.foldername(name))[2]=auth.uid()::text and
  not exists(select 1 from public.media_assets m where m.storage_key=name)
);
