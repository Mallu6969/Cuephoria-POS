# Table Comparison: Migration File vs Database

## Tables in Migration File (42 tables)

1. admin_users
2. categories
3. stations
4. products
5. customers
6. bills
7. bill_items
8. bookings
9. sessions
10. expenses
11. **subscription** ⚠️
12. **pending_payments** ⚠️
13. cash_vault
14. cash_vault_transactions
15. cash_bank_deposits
16. cash_deposits
17. cash_transactions
18. cash_summary
19. tournaments
20. tournament_history
21. tournament_winners
22. tournament_public_registrations
23. tournament_registrations
24. tournament_winner_images
25. loyalty_transactions
26. rewards
27. reward_redemptions
28. referrals
29. staff_profiles
30. staff_attendance
31. staff_leave_requests
32. staff_work_schedules
33. promotions
34. offers
35. notifications
36. notification_templates
37. email_templates
38. booking_views
39. customer_users
40. investment_partners
41. investment_transactions
42. user_preferences

## Tables in Database (from types.ts - 40 tables)

1. admin_users ✅
2. bill_items ✅
3. bills ✅
4. booking_views ✅
5. bookings ✅
6. cash_bank_deposits ✅
7. cash_deposits ✅
8. cash_summary ✅
9. cash_transactions ✅
10. cash_vault ✅
11. cash_vault_transactions ✅
12. categories ✅
13. customer_users ✅
14. customers ✅
15. email_templates ✅
16. expenses ✅
17. investment_partners ✅
18. investment_transactions ✅
19. loyalty_transactions ✅
20. notification_templates ✅
21. notifications ✅
22. offers ✅
23. products ✅
24. promotions ✅
25. referrals ✅
26. reward_redemptions ✅
27. rewards ✅
28. sessions ✅
29. staff_attendance ✅
30. staff_leave_requests ✅
31. staff_profiles ✅
32. staff_work_schedules ✅
33. stations ✅
34. tournament_history ✅
35. tournament_public_registrations ✅
36. tournament_registrations ✅
37. tournament_winner_images ✅
38. tournament_winners ✅
39. tournaments ✅
40. user_preferences ✅

## Missing Tables (2 tables)

The following tables are defined in the migration file but **NOT found in the database**:

1. **subscription** - Subscription management table
   - Location in migration: Line 182
   - Purpose: Stores subscription information (is_active, subscription_type, start_date, end_date, etc.)

2. **pending_payments** - Payment reconciliation table
   - Location in migration: Line 204
   - Purpose: Stores payment intents for reconciliation with Razorpay (razorpay_order_id, razorpay_payment_id, booking_data, etc.)

## Summary

- **Total tables in migration**: 42
- **Total tables in database**: 40
- **Missing tables**: 2 (subscription, pending_payments)

These missing tables are critical for:
- Subscription management functionality
- Payment reconciliation with Razorpay

