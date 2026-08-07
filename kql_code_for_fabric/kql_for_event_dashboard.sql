-- Fetch total message count in the last 5 minutes
['neondb.public.messages_v1']
| where created_at >= ago(5m)
| summarize total_messages = count()


-- Calculate total new users registered in the last 1 hour

['neondb.public.users_v1']
| where created_at >= ago(1h)
| summarize total_users = count()

-- Calculate total error messages in the last 5 minutes
['neondb.public.messages_v1']
|where created_at >= ago(5m) and is_error
| summarize total_error_messages = count()

-- Calculate total new VIP subscription users in the last 1 hour
['neondb.public.user_subscriptions_v1']
| where (start_time >= ago(1h)) and  (plan_id in ('plan_basic','plan_ultra'))
| summarize total_vip_users = count()

-- Track total user count trend over the last 24 hours
['neondb.public.users_v1']
| where created_at >= ago(1d)
| summarize total_users = count() by created_at
| project total_users, created_at