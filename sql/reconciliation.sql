-- Total order revenue (raw, from orders table)
SELECT SUM(revenue) AS total_order_revenue
FROM orders;

-- Total attributed revenue
WITH session_order_match AS (
	SELECT
		o.order_id,
		o.customer_id,
		o.order_date,
		o.revenue,
		s.session_id,
		s.campaign_id,
		s.date AS session_date,
		ROW_NUMBER() OVER (
			PARTITION BY o.order_id
			ORDER BY s.date DESC
		) AS rn
	FROM orders o
	JOIN web_sessions s
		on o.customer_id = s.customer_id
		AND s.date <= o.order_date
),
attributed_orders AS (
	SELECT order_id, campaign_id, order_date, revenue
	FROM session_order_match
	WHERE rn = 1
)
SELECT SUM(revenue) AS total_attributed_revenue
FROM attributed_orders;