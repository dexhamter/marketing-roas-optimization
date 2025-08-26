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
		ON o.customer_id = s.customer_id
		AND s.date <= o.order_date
),
attributed_orders AS (
	SELECT order_id, campaign_id, order_date, revenue
	FROM session_order_match
	WHERE rn = 1
),
revenue_by_campaign AS (
	SELECT
		ao.campaign_id,
		c.channel,
		SUM(ao.revenue) AS total_revenue
	FROM attributed_orders ao
	JOIN campaigns c
		ON ao.campaign_id = c.campaign_id
	GROUP BY ao.campaign_id, c.channel
),
spend_by_campaign AS (
	SELECT
		sp.campaign_id,
		c.channel,
		SUM(sp.spend) AS total_spend
	FROM ad_spend_daily sp
	JOIN campaigns c
		ON sp.campaign_id = c.campaign_id
	GROUP BY sp.campaign_id, c.channel
)
SELECT
	r.campaign_id,
	r.channel,
	r.total_revenue,
	s.total_spend,
	CASE
		WHEN s.total_spend = 0 THEN NULL
		ELSE r.total_revenue * 1.0 / s.total_spend
	END AS roas
FROM revenue_by_campaign r
LEFT JOIN spend_by_campaign s
	ON r.campaign_id = s.campaign_id;
	
-- Campaigns -> channel validation
WITH campaign_table AS (
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
			ON o.customer_id = s.customer_id
			AND s.date <= o.order_date
	),
	attributed_orders AS (
		SELECT order_id, campaign_id, order_date, revenue
		FROM session_order_match
		WHERE rn = 1
	),
	revenue_by_campaign AS (
		SELECT
			ao.campaign_id,
			c.channel,
			SUM(ao.revenue) AS total_revenue
		FROM attributed_orders ao
		JOIN campaigns c
			ON ao.campaign_id = c.campaign_id
		GROUP BY ao.campaign_id, c.channel
	),
	spend_by_campaign AS (
		SELECT
			sp.campaign_id,
			c.channel,
			SUM(sp.spend) AS total_spend
		FROM ad_spend_daily sp
		JOIN campaigns c
			ON sp.campaign_id = c.campaign_id
		GROUP BY sp.campaign_id, c.channel
	)
	SELECT
		r.campaign_id,
		r.channel,
		r.total_revenue,
		s.total_spend,
		CASE
			WHEN s.total_spend = 0 THEN NULL
			ELSE r.total_revenue * 1.0 / s.total_spend
		END AS roas
	FROM revenue_by_campaign r
	LEFT JOIN spend_by_campaign s
		ON r.campaign_id = s.campaign_id
)
SELECT
	channel,
	ROUND(SUM(total_revenue),2) AS revenue,
	ROUND(SUM(total_spend),2) AS spend
FROM campaign_table
GROUP BY channel
ORDER BY revenue DESC;

-- From campaign table
WITH campaign_table AS (
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
			ON o.customer_id = s.customer_id
			AND s.date <= o.order_date
	),
	attributed_orders AS (
		SELECT order_id, campaign_id, order_date, revenue
		FROM session_order_match
		WHERE rn = 1
	),
	revenue_by_campaign AS (
		SELECT
			ao.campaign_id,
			c.channel,
			SUM(ao.revenue) AS total_revenue
		FROM attributed_orders ao
		JOIN campaigns c
			ON ao.campaign_id = c.campaign_id
		GROUP BY ao.campaign_id, c.channel
	),
	spend_by_campaign AS (
		SELECT
			sp.campaign_id,
			c.channel,
			SUM(sp.spend) AS total_spend
		FROM ad_spend_daily sp
		JOIN campaigns c
			ON sp.campaign_id = c.campaign_id
		GROUP BY sp.campaign_id, c.channel
	)
	SELECT
		r.campaign_id,
		r.channel,
		r.total_revenue,
		s.total_spend,
		CASE
			WHEN s.total_spend = 0 THEN NULL
			ELSE r.total_revenue * 1.0 / s.total_spend
		END AS roas
	FROM revenue_by_campaign r
	LEFT JOIN spend_by_campaign s
		ON r.campaign_id = s.campaign_id
)
SELECT ROUND(SUM(total_revenue),2) AS campaign_sum FROM campaign_table;

-- Direct from attributed_orders
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
		ON o.customer_id = s.customer_id
		AND s.date <= o.order_date
),
attributed_orders AS (
	SELECT order_id, campaign_id, order_date, revenue
	FROM session_order_match
	WHERE rn = 1
)
SELECT ROUND(SUM(revenue),2) AS attributed_revenue FROM attributed_orders;