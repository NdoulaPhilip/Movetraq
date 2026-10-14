begin;
create or replace function eligible_job_ids(p_deliverer uuid) returns table(order_id uuid) language sql stable set search_path=public as $$
 select o.id from orders o join deliverers d on d.user_id=p_deliverer join profiles p on p.id=d.user_id
 where d.available and d.verification_status='approved' and p.status='active' and o.sender_id<>p_deliverer
 and not exists(select 1 from business_config c where c.key='supported_transport_types' and not (c.value ? d.transport))
 and o.status in ('awaiting_deliverer','offer_received') and o.payment_status='paid' and o.service_type=any(d.service_preferences)
 and (o.service_details->>'preferred_deliverer_id' is null or o.service_details->>'preferred_deliverer_id'=p_deliverer::text)
 and d.area_center_lat is not null and d.area_center_lng is not null and o.parcel_weight_kg<=d.capacity_kg
 and (o.service_type<>'big_move' or (d.vehicle_class=o.service_details->>'vehicle' and d.transport in ('car','van','other_motor')))
 and not exists(select 1 from blocked_users b where (b.user_id=p_deliverer and b.blocked_user_id=o.sender_id) or (b.user_id=o.sender_id and b.blocked_user_id=p_deliverer))
 and (select count(*) from orders a where a.deliverer_id=p_deliverer and a.status not in ('completed','cancelled','returned','failed','rejected'))<d.max_active_jobs
 and 6371000*2*asin(sqrt(least(1,power(sin(radians((o.pickup->>'latitude')::numeric-d.area_center_lat)/2),2)+cos(radians(d.area_center_lat))*cos(radians((o.pickup->>'latitude')::numeric))*power(sin(radians((o.pickup->>'longitude')::numeric-d.area_center_lng)/2),2))))<=d.area_radius_metres
$$;
revoke all on function eligible_job_ids(uuid) from public,anon,authenticated;
commit;
