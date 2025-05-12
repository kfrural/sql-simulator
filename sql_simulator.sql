--TASK 1
/*Для каждого дня, представленного в таблицах user_actions и courier_actions, рассчитайте следующие показатели:

Число новых пользователей.
Число новых курьеров.
Общее число пользователей на текущий день.
Общее число курьеров на текущий день.*/

WITH new_users AS (
    SELECT 
        time::date as date,
        user_id,
        row_number() OVER(PARTITION BY user_id ORDER BY time::date) as num_user
    FROM user_actions
),
new_couriers AS (
    SELECT 
        time::date as date,
        courier_id,
        row_number() OVER(PARTITION BY courier_id ORDER BY time::date) as num_courier
    FROM courier_actions
),
daily_counts AS (
    SELECT 
        COALESCE(nu.date, nc.date) as date,
        COUNT(DISTINCT nu.user_id) as new_users,
        COUNT(DISTINCT nc.courier_id) as new_couriers
    FROM new_users nu
    FULL OUTER JOIN new_couriers nc 
        ON nu.date = nc.date
    WHERE nu.num_user = 1 OR nu.num_user IS NULL
    AND nc.num_courier = 1 OR nc.num_courier IS NULL
    GROUP BY COALESCE(nu.date, nc.date)
)
SELECT 
    date,
    new_users,
    new_couriers,
    SUM(new_couriers) OVER(ORDER BY date) as total_couriers,
    SUM(new_users) OVER(ORDER BY date) as total_users
FROM daily_counts
ORDER BY date;


--TASK 2
/*Дополните запрос из предыдущего задания и теперь для каждого дня, представленного в таблицах user_actions и courier_actions, дополнительно рассчитайте следующие показатели:

Прирост числа новых пользователей.
Прирост числа новых курьеров.
Прирост общего числа пользователей.
Прирост общего числа курьеров.*/

WITH base_metrics AS (
    SELECT 
        date,
        new_users,
        new_couriers,
        total_couriers,
        total_users
    FROM (
        WITH new_users AS (
            SELECT 
                time::date as date,
                user_id,
                row_number() OVER(PARTITION BY user_id ORDER BY time::date) as num_user
            FROM user_actions
        ),
        new_couriers AS (
            SELECT 
                time::date as date,
                courier_id,
                row_number() OVER(PARTITION BY courier_id ORDER BY time::date) as num_courier
            FROM courier_actions
        ),
        daily_counts AS (
            SELECT 
                COALESCE(nu.date, nc.date) as date,
                COUNT(DISTINCT nu.user_id) as new_users,
                COUNT(DISTINCT nc.courier_id) as new_couriers
            FROM new_users nu
            FULL OUTER JOIN new_couriers nc 
                ON nu.date = nc.date
            WHERE nu.num_user = 1 OR nu.num_user IS NULL
            AND nc.num_courier = 1 OR nc.num_courier IS NULL
            GROUP BY COALESCE(nu.date, nc.date)
        )
        SELECT 
            date,
            new_users,
            new_couriers,
            SUM(new_couriers) OVER(ORDER BY date) as total_couriers,
            SUM(new_users) OVER(ORDER BY date) as total_users
        FROM daily_counts
    ) as base
)
SELECT 
    date,
    new_users,
    new_couriers,
    total_couriers,
    total_users,
    ROUND(
        100.0 * (
            LAG(new_users) OVER(ORDER BY date) - new_users
        ) / LAG(new_users) OVER(ORDER BY date),
        2
    ) as new_users_change,
    ROUND(
        100.0 * (
            LAG(new_couriers) OVER(ORDER BY date) - new_couriers
        ) / LAG(new_couriers) OVER(ORDER BY date),
        2
    ) as new_couriers_change,
    ROUND(
        100.0 * (
            LAG(total_couriers) OVER(ORDER BY date) - total_couriers
        ) / LAG(total_couriers) OVER(ORDER BY date),
        2
    ) as total_couriers_growth,
    ROUND(
        100.0 * (
            LAG(total_users) OVER(ORDER BY date) - total_users
        ) / LAG(total_users) OVER(ORDER BY date),
        2
    ) as total_users_growth
FROM base_metrics
ORDER BY date;


--TASK 3
/*Для каждого дня, представленного в таблицах user_actions и courier_actions, рассчитайте следующие показатели:

Число платящих пользователей.
Число активных курьеров.
Долю платящих пользователей в общем числе пользователей на текущий день.
Долю активных курьеров в общем числе курьеров на текущий день.*/

WITH paying_users AS (
    SELECT 
        time::date as date,
        COUNT(DISTINCT user_id) as paying_users
    FROM user_actions
    WHERE order_id NOT IN (
        SELECT order_id 
        FROM user_actions 
        WHERE action = 'cancel_order'
    )
    GROUP BY time::date
),
active_couriers AS (
    SELECT 
        time::date as date,
        COUNT(DISTINCT courier_id) as active_couriers
    FROM courier_actions
    WHERE order_id IN (
        SELECT order_id 
        FROM courier_actions 
        WHERE action = 'deliver_order'
    )
    GROUP BY time::date
),
total_users AS (
    SELECT 
        date,
        COUNT(DISTINCT user_id) as total_users
    FROM (
        SELECT 
            user_id,
            time::date as date,
            row_number() OVER(PARTITION BY user_id ORDER BY time::date) as num_user
        FROM user_actions
    ) as tmp
    WHERE num_user = 1
    GROUP BY date
),
total_couriers AS (
    SELECT 
        date,
        COUNT(DISTINCT courier_id) as total_couriers
    FROM (
        SELECT 
            courier_id,
            time::date as date,
            row_number() OVER(PARTITION BY courier_id ORDER BY time::date) as num_courier
        FROM courier_actions
    ) as tmp
    WHERE num_courier = 1
    GROUP BY date
)
SELECT 
    pu.date,
    pu.paying_users,
    ac.active_couriers,
    ROUND(100.0 * pu.paying_users / tu.total_users, 2) as paying_users_share,
    ROUND(100.0 * ac.active_couriers / tc.total_couriers, 2) as active_couriers_share
FROM paying_users pu
JOIN active_couriers ac ON pu.date = ac.date
JOIN total_users tu ON pu.date = tu.date
JOIN total_couriers tc ON pu.date = tc.date
ORDER BY pu.date;
  
  
--TASK 4
/*Для каждого дня, представленного в таблице user_actions, рассчитайте следующие показатели:

Долю пользователей, сделавших в этот день всего один заказ, в общем количестве платящих пользователей.
Долю пользователей, сделавших в этот день несколько заказов, в общем количестве платящих пользователей.*/

WITH paying_users AS (
    SELECT 
        time::date as date,
        COUNT(DISTINCT user_id) as total_paid_users
    FROM user_actions
    WHERE order_id NOT IN (
        SELECT order_id 
        FROM user_actions 
        WHERE action = 'cancel_order'
    )
    GROUP BY time::date
),
single_order_users AS (
    SELECT 
        date,
        COUNT(DISTINCT user_id) as num_users_1
    FROM (
        SELECT 
            user_id,
            time::date as date,
            COUNT(DISTINCT order_id) as order_count
        FROM user_actions
        WHERE order_id NOT IN (
            SELECT order_id 
            FROM user_actions 
            WHERE action = 'cancel_order'
        )
        GROUP BY user_id, time::date
        HAVING COUNT(DISTINCT order_id) = 1
    ) as tmp
    GROUP BY date
),
multiple_order_users AS (
    SELECT 
        date,
        COUNT(DISTINCT user_id) as num_users
    FROM (
        SELECT 
            user_id,
            time::date as date,
            COUNT(DISTINCT order_id) as order_count
        FROM user_actions
        WHERE order_id NOT IN (
            SELECT order_id 
            FROM user_actions 
            WHERE action = 'cancel_order'
        )
        GROUP BY user_id, time::date
        HAVING COUNT(DISTINCT order_id) > 1
    ) as tmp
    GROUP BY date
)
SELECT 
    pu.date,
    ROUND(100.0 * COALESCE(sou.num_users_1, 0) / pu.total_paid_users, 2) as single_order_users_share,
    ROUND(100.0 * COALESCE(mou.num_users, 0) / pu.total_paid_users, 2) as several_orders_users_share
FROM paying_users pu
LEFT JOIN single_order_users sou ON pu.date = sou.date
LEFT JOIN multiple_order_users mou ON pu.date = mou.date
ORDER BY pu.date;


--TASK 5
/*Для каждого дня, представленного в таблице user_actions, рассчитайте следующие показатели:

Общее число заказов.
Число первых заказов (заказов, сделанных пользователями впервые).
Число заказов новых пользователей (заказов, сделанных пользователями в тот же день, когда они впервые воспользовались сервисом).
Долю первых заказов в общем числе заказов (долю п.2 в п.1).
Долю заказов новых пользователей в общем числе заказов (долю п.3 в п.1).*/


WITH orders AS (
    SELECT 
        time::date as date,
        COUNT(DISTINCT order_id) as orders,
        COUNT(CASE WHEN num_user = 1 THEN user_id END) as first_orders
    FROM user_actions
    WHERE order_id NOT IN (
        SELECT order_id 
        FROM user_actions 
        WHERE action = 'cancel_order'
    )
    GROUP BY time::date
),
new_users_orders AS (
    SELECT 
        tm1.date as date,
        COUNT(order_id) as new_users_orders
    FROM (
        SELECT 
            MIN(time::date) as date,
            user_id
        FROM user_actions
        GROUP BY user_id
    ) as tm1
    LEFT JOIN (
        SELECT 
            time::date as date,
            user_id,
            order_id
        FROM user_actions
        WHERE order_id NOT IN (
            SELECT order_id 
            FROM user_actions 
            WHERE action = 'cancel_order'
        )
    ) as tm2 ON tm1.date = tm2.date
    AND tm1.user_id = tm2.user_id
    GROUP BY tm1.date
)
SELECT 
    o.date,
    o.orders,
    o.first_orders,
    nou.new_users_orders,
    ROUND(100.0 * o.first_orders / o.orders, 2) as first_orders_share,
    ROUND(100.0 * nou.new_users_orders / o.orders, 2) as new_users_orders_share
FROM orders o
LEFT JOIN new_users_orders nou ON o.date = nou.date
ORDER BY o.date;
  


--TASK 6
/*На основе данных в таблицах user_actions, courier_actions и orders для каждого дня рассчитайте следующие показатели:

Число платящих пользователей на одного активного курьера.
Число заказов на одного активного курьера.*/


WITH active_couriers AS (
    SELECT 
        time::date as date,
        COUNT(DISTINCT courier_id) as active_couriers
    FROM courier_actions
    WHERE order_id IN (
        SELECT order_id 
        FROM courier_actions 
        WHERE action = 'deliver_order'
    )
    GROUP BY time::date
),
paying_users AS (
    SELECT 
        time::date as date,
        COUNT(DISTINCT user_id) as paying_users
    FROM user_actions
    WHERE order_id NOT IN (
        SELECT order_id 
        FROM user_actions 
        WHERE action = 'cancel_order'
    )
    GROUP BY time::date
),
orders AS (
    SELECT 
        time::date as date,
        COUNT(DISTINCT order_id) as orders
    FROM user_actions
    WHERE order_id NOT IN (
        SELECT order_id 
        FROM user_actions 
        WHERE action = 'cancel_order'
    )
    GROUP BY time::date
)
SELECT 
    ac.date,
    ROUND(pu.paying_users::decimal / ac.active_couriers, 2) as users_per_courier,
    ROUND(o.orders::decimal / ac.active_couriers, 2) as orders_per_courier
FROM active_couriers ac
LEFT JOIN paying_users pu ON ac.date = pu.date
LEFT JOIN orders o ON ac.date = o.date
ORDER BY ac.date;
  
  
  
--TASK 7
/*На основе данных в таблице courier_actions для каждого дня рассчитайте, за сколько минут в среднем курьеры доставляли свои заказы.*/


WITH delivery_times AS (
    SELECT 
        ca1.order_id,
        ca1.time as accept_time,
        ca2.time as deliver_time
    FROM courier_actions ca1
    INNER JOIN courier_actions ca2 ON ca1.order_id = ca2.order_id
    WHERE ca1.action = 'accept_order'
    AND ca2.action = 'deliver_order'
)
SELECT 
    dt.accept_time::date as date,
    ROUND(AVG(EXTRACT(EPOCH FROM (dt.deliver_time - dt.accept_time)) / 60)) as minutes_to_deliver
FROM delivery_times dt
GROUP BY dt.accept_time::date
ORDER BY date;



--TASK 8
/*На основе данных в таблице orders для каждого часа в сутках рассчитайте следующие показатели:

Число успешных (доставленных) заказов.
Число отменённых заказов.
Долю отменённых заказов в общем числе заказов (cancel rate).*/

WITH successful_orders AS (
    SELECT 
        DATE_PART('hour', creation_time) as hour,
        COUNT(DISTINCT order_id) as successful_orders
    FROM orders
    WHERE order_id IN (
        SELECT order_id 
        FROM courier_actions 
        WHERE action = 'deliver_order'
    )
    GROUP BY DATE_PART('hour', creation_time)
),
canceled_orders AS (
    SELECT 
        DATE_PART('hour', creation_time) as hour,
        COUNT(DISTINCT order_id) as canceled_orders
    FROM orders
    WHERE order_id IN (
        SELECT order_id 
        FROM user_actions 
        WHERE action = 'cancel_order'
    )
    GROUP BY DATE_PART('hour', creation_time)
)
SELECT 
    so.hour as successful_hour,
    so.successful_orders,
    co.canceled_orders,
    ROUND(co.canceled_orders::decimal / (so.successful_orders + co.canceled_orders), 3) as cancel_rate
FROM successful_orders so
LEFT JOIN canceled_orders co ON so.hour = co.hour
ORDER BY so.hour;
where order_id in (select order_id
from user_actions
where action ='cancel_order') 
group by canceled_hour) as tmp2
on tmp1.successful_hour = tmp2.canceled_hour
