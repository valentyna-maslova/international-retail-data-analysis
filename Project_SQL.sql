-- =========================================
-- 1. ПРОЄКТУВАННЯ І НОРМАЛІЗАЦІЯ БАЗИ ДАНИХ
-- =========================================

-- 1.1 Створення таблиць
CREATE TABLE order_dates (
order_date TIMESTAMP NOT NULL PRIMARY KEY,
year_num INT NOT NULL,
month_num INT NOT NULL,
quarter VARCHAR(50) NOT NULL,
season VARCHAR(50) NOT NULL
);

CREATE TABLE locations (
location_id SERIAL PRIMARY KEY,
country VARCHAR(50) NOT NULL UNIQUE,
region VARCHAR(50) NOT NULL,
currency VARCHAR(5) NOT NULL
);

CREATE TABLE customers (
customer_id VARCHAR(50) NOT NULL PRIMARY KEY,
customer_gender VARCHAR(50) NOT NULL,
customer_segment VARCHAR(50) NOT NULL
);

CREATE TABLE products (
product_id SERIAL PRIMARY KEY,
product_name TEXT NOT NULL UNIQUE,
category VARCHAR(50) NOT NULL,
sub_category VARCHAR(50) NOT NULL,
unit_price NUMERIC(10, 2) NOT NULL,
CONSTRAINT chk_unit_price CHECK (unit_price > 0)
);

CREATE TABLE orders (
order_id INT NOT NULL PRIMARY KEY,
order_date TIMESTAMP NOT NULL,
customer_id VARCHAR(50) NOT NULL,
location_id INT NOT NULL,
product_id INT NOT NULL,
base_price NUMERIC(10, 2) NOT NULL,
quantity INT NOT NULL,
discount NUMERIC(10, 2) NOT NULL,
revenue NUMERIC(10, 2) NOT NULL,
costs NUMERIC(10, 2) NOT NULL,
profit NUMERIC(10, 2) NOT NULL,
profit_margin_pct NUMERIC(10, 2) NOT NULL,
shipping_cost NUMERIC(10, 2) NOT NULL,
shipping_method VARCHAR(50) NOT NULL,
shipping_days INT NOT NULL,
payment_method VARCHAR(50) NOT NULL,
order_status VARCHAR(50) NOT NULL,
exchange_rate_usd NUMERIC(10, 2) NOT NULL,
is_unprofitable BOOLEAN NOT NULL,
CONSTRAINT chk_discount CHECK (discount >= 0 AND discount <= 0.5),
CONSTRAINT chk_quantity CHECK (quantity > 0),
CONSTRAINT chk_shipping_days CHECK (shipping_days > 0),
CONSTRAINT chk_base_price CHECK (base_price > 0),
FOREIGN KEY (order_date) REFERENCES order_dates(order_date),
FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
FOREIGN KEY (location_id) REFERENCES locations(location_id),
FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- 1.2 Заповнення таблиць даними та перевірка результатів

INSERT INTO order_dates (order_date, year_num, month_num, quarter, season)
SELECT DISTINCT 
    "Order_Date",
    "Year",
    "Month",
    "Quarter",
    "Season"
FROM ecommerce_sales
ORDER BY "Order_Date";

SELECT COUNT(*) FROM order_dates;
SELECT * FROM order_dates LIMIT 5;

INSERT INTO locations (country, region, currency)
SELECT DISTINCT 
    "Country",
    "Region",
    "Currency"
FROM ecommerce_sales
ORDER BY "Country";

SELECT COUNT(*) FROM locations;
SELECT * FROM locations ORDER BY location_id LIMIT 5;

-- В процесі нормалізації бази даних було виявлено , що один і той самий 
-- customer_id мав різні значення атрибутів, зокрема сегмент клієнта (customer_segment). 
-- Це свідчить про те, що сегмент клієнта змінювався з часом (наприклад, у 2021 році 
-- клієнт міг належати до сегменту Regular, а у 2024 році перейти до сегменту VIP.
-- Для таблиці customers обрано актуальний на останню дату продажу сегмент клієнта.
-- Це реалізовано за допомогою оператора DISTINCT ON з сортуванням за датою замовлення
-- у порядку спадання (ORDER BY customer_id, order_date DESC), що дозволяє отримати
-- найактуальніший сегмент для кожного унікального клієнта.

-- Таким чином, таблиця customers містить поточний статус клієнта,
-- тоді як повна історія його замовлень зберігається в таблиці orders.

INSERT INTO customers (customer_id, customer_gender, customer_segment)
SELECT DISTINCT ON ("Customer_ID")
    "Customer_ID",
    "Customer_Gender",
    "Customer_Segment"
FROM ecommerce_sales
ORDER BY "Customer_ID", "Order_Date" DESC;

SELECT COUNT(*) FROM customers;
SELECT * FROM customers ORDER BY customer_id LIMIT 5;

-- В процесі нормалізації було виявлено, що один і той самий товар зустрічається
-- в вихідному датасеті з різними значеннями ціни, що свідчить про динамічне
-- ціноутворення (зміна вартості товару з часом). Для таблиці products обрано 
-- актуальну ціну товару станом на останню дату продажу. Це реалізовано за допомогою
-- оператора DISTINCT ON з сортуванням за датою замовлення у порядку спадання 
-- (ORDER BY product_name, order_date DESC), що дозволяє отримати найновіший запис 
-- для кожного унікального товару.

-- Таким чином, таблиця products містить актуальний прайс-лист товарів, 
-- тоді як історична ціна кожного конкретного продажу зберігається в таблиці orders
-- у колонці base_price.

INSERT INTO products (product_name, category, sub_category, unit_price)
SELECT DISTINCT ON ("Product_Name")
    "Product_Name",
    "Category",
    "Sub_Category",
    "Unit_Price"
FROM ecommerce_sales
ORDER BY "Product_Name", "Order_Date" DESC;

SELECT COUNT(*) FROM products;
SELECT * FROM products ORDER BY product_id LIMIT 5;


INSERT INTO orders (order_id, order_date, customer_id, location_id, product_id,
                    base_price, quantity, discount, revenue, costs, profit,
                    profit_margin_pct, shipping_cost, shipping_method,
                    shipping_days, payment_method, order_status, exchange_rate_usd,
                    is_unprofitable)
SELECT 
    "Order_ID",
    "Order_Date",
    "Customer_ID",
    (SELECT location_id FROM locations WHERE country = e."Country"),
    (SELECT product_id FROM products WHERE product_name = e."Product_Name"),
    "Unit_Price",
    "Quantity",
    "Discount",
    "Revenue",
    "Cost",
    "Profit",
    "Profit_Margin_%",
    "Shipping_Cost",
    "Shipping_Method",
    "Shipping_Days",
    "Payment_Method",
    "Order_Status",
    "Exchange_Rate_USD",
    "is_unprofitable"
FROM ecommerce_sales e;

SELECT COUNT(*) FROM orders;
SELECT * FROM orders ORDER BY order_id LIMIT 5;

-- GENERATED COLUMN

-- base_revenue — згенерований додатковий стовпець базової виручки до застосування 
-- знижки для таблиці orders, обчислюється автоматично як добуток ціни (base_price) 
-- на кількість (quantity)

ALTER TABLE orders 
ADD COLUMN base_revenue NUMERIC(10,2) 
GENERATED ALWAYS AS (base_price * quantity) STORED;

SELECT order_id, base_price, quantity, base_revenue, revenue 
FROM orders 
LIMIT 5;

-- 1.3. Створення VIEW для подальшого аналізу.

-- 1.3.1. Продажі за роками та країнами.

CREATE VIEW v_sales_by_country_year AS
SELECT 
    l.country,
    l.region,
    date_part('year', o.order_date)::INT AS order_year,
    COUNT(o.order_id) AS total_orders,
    SUM(o.revenue) AS total_revenue,
    SUM(o.profit) AS total_profit,
    ROUND(AVG(o.profit_margin_pct)::numeric, 2) AS avg_margin
FROM orders o
JOIN locations l ON o.location_id = l.location_id
GROUP BY l.country, l.region, date_part('year', o.order_date);

SELECT * FROM v_sales_by_country_year LIMIT 5;

-- 1.3.2. Продажі за категоріями.

CREATE VIEW v_sales_by_category AS
SELECT 
    p.category,
    p.sub_category,
    COUNT(o.order_id) AS total_orders,
    SUM(o.revenue) AS total_revenue,
    SUM(o.profit) AS total_profit,
    ROUND(AVG(o.discount)::numeric, 2) AS avg_discount
FROM orders o
JOIN products p ON o.product_id = p.product_id
GROUP BY p.category, p.sub_category;

SELECT * FROM v_sales_by_category LIMIT 5;

-- 1.3.3. Збиткові замовлення.

CREATE VIEW v_unprofitable_orders AS
SELECT 
    o.order_id,
    l.country,
    p.category,
    o.discount,
    o.profit,
    o.is_unprofitable
FROM orders o
JOIN locations l ON o.location_id = l.location_id
JOIN products p ON o.product_id = p.product_id
WHERE o.is_unprofitable = TRUE;

SELECT * FROM v_unprofitable_orders LIMIT 5;

-- 1.3.4. Динаміка продажів за місяцями.

CREATE VIEW v_monthly_dynamics AS
SELECT 
    date_part('year', o.order_date)::INT AS order_year,
    date_part('month', o.order_date)::INT AS order_month,
    COUNT(o.order_id) AS total_orders,
    SUM(o.revenue) AS total_revenue,
    SUM(o.profit) AS total_profit
FROM orders o
GROUP BY date_part('year', o.order_date),
         date_part('month', o.order_date);

SELECT * FROM v_monthly_dynamics ORDER BY order_year, order_month LIMIT 5;

-- =========================================
-- 2. АНАЛІТИЧНІ ЗАПИТИ 
-- =========================================

-- 2.1 Запит на визначення країни-відправника

-- 2.1.1. Знаходження мінімального строку доставки для кожної країни
WITH country_method_shipping AS (
    SELECT 
        l.region,
        l.country,
        o.shipping_method,
        MIN(o.shipping_days) AS min_shipping_days,
        COUNT(o.order_id) AS total_orders
    FROM orders o
    JOIN locations l ON o.location_id = l.location_id
    GROUP BY l.region, l.country, o.shipping_method
)
SELECT 
    region,
    country,
    shipping_method,
    min_shipping_days,
    total_orders
FROM country_method_shipping
ORDER BY region ASC, country ASC, min_shipping_days ASC, shipping_method ASC;

-- Висновок: За результатами розрахунку регіоном відправки товарів однозначно є Північна Америка.
-- Три країни цього регіону - Мексика, Канада і США - мають найменший строк доставки: 3 дні.
-- При цьому виявлено аномалію вихідного датасету: повна відсутність кореляції між методами доставки
-- (Overnight, Economy, Express, Standard) та фактичними строками транзиту (shipping_days). 
-- Для всіх логістичних продуктів зафіксовано ідентичні терміни доставки, що унеможливлює остаточного
-- визначення країни-відправника.

-- 2.1.2. Структурний аналіз асортименту продажів в розрізі ринків збуту для веріфікації
-- гіпотези про країну походження бренду

SELECT 
    p.category,
    p.sub_category,
    SUM(CASE WHEN l.country = 'USA' THEN o.quantity ELSE 0 END) AS sales_in_usa,
    SUM(o.quantity) AS total_global_sales,
    ROUND(
        100.0 * SUM(CASE WHEN l.country = 'USA' THEN o.quantity ELSE 0 END) / SUM(o.quantity), 
        2
    ) AS usa_sales_share_pct
FROM orders o
JOIN products p ON o.product_id = p.product_id
JOIN locations l ON o.location_id = l.location_id
GROUP BY p.category, p.sub_category
ORDER BY total_global_sales DESC;

-- Висновок: Аналіз категорій та підкатегорій товарів у розрізі регіонів збуту показав рівномірний
-- розподіл частоти замовлень. Частка ринку США для всіх категорій продукції стабільно коливається
-- в межах 6–10% від загального обсягу глобальних продажів.
-- Таким чином, товарний асортимент не може виступати надійним ідентифікатором країни походження бренду.

-- 2.1.3. Аналіз вартості доставки за різними методами доставки
SELECT 
    l.region,
    o.shipping_method,
    ROUND(AVG(o.shipping_cost), 2) AS avg_shipping_cost,
    MIN(o.shipping_cost) AS min_shipping_cost,
    MAX(o.shipping_cost) AS max_shipping_cost,
    COUNT(o.order_id) AS total_orders
FROM orders o
JOIN locations l ON o.location_id = l.location_id
GROUP BY l.region, o.shipping_method
ORDER BY l.region ASC, avg_shipping_cost ASC;

-- Висновок: Аналіз виявив одну логістичну аномалію вихідного датасету: однакові терміни доставки
-- для всіх методів в межах одного регіону — незалежно від методу (Economy, Standard, Express, Overnight)
-- термін був ідентичним, що суперечить реальній логістиці D2C-бренду.
-- Водночас єдина фіксована вартість доставки для всіх регіонів
-- (Economy ~$6, Standard ~$12, Express ~$35, Overnight ~$75) може бути свідомою стратегією ціноутворення
-- бренду, що пояснює рівномірний розподіл замовлень між регіонами незалежно від географічної відстані.
-- На підставі аналізу прийнято рішення визначити США як імовірну країну розташування
-- фулфілмент-центру бренду та скоригувати терміни доставки відповідно до реальної
-- географічної логістики D2C-сегменту.

-- 2.1.4. Корегування строків доставки в залежності від регіону та методів доставки

-- США (USA), країна відправки — найшвидка логістика без митниці
UPDATE orders o
SET shipping_days = CASE 
    WHEN o.shipping_method = 'Overnight' THEN 1
    WHEN o.shipping_method = 'Express' THEN 2
    WHEN o.shipping_method = 'Standard' THEN 3
    ELSE 5 -- Economy
END
FROM locations l
WHERE o.location_id = l.location_id AND l.country = 'USA';

-- КАНАДА І МЕКСИКА (Canada, Mexico) — додається 1-2 дні обробки на митниці
UPDATE orders o
SET shipping_days = CASE 
    WHEN o.shipping_method = 'Overnight' THEN 2
    WHEN o.shipping_method = 'Express' THEN 3
    WHEN o.shipping_method = 'Standard' THEN 5
    ELSE 7 -- Economy
END
FROM locations l
WHERE o.location_id = l.location_id AND l.country IN ('Canada', 'Mexico');

-- ЄВРОПА (Europe) — авіа-доставка через Атлантику
UPDATE orders o
SET shipping_days = CASE 
    WHEN o.shipping_method = 'Overnight' THEN 2 -- Ідеальний экспресс-транзит
    WHEN o.shipping_method = 'Express' THEN 4
    WHEN o.shipping_method = 'Standard' THEN 6
    ELSE 10 -- Economy
END
FROM locations l
WHERE o.location_id = l.location_id AND l.region = 'Europe';

-- Близький Схід (Middle East)
UPDATE orders o
SET shipping_days = CASE 
    WHEN o.shipping_method = 'Overnight' THEN 3
    WHEN o.shipping_method = 'Express' THEN 5
    WHEN o.shipping_method = 'Standard' THEN 7
    ELSE 12 -- Economy
END
FROM locations l
WHERE o.location_id = l.location_id AND l.region = 'Middle East';

-- Азія (Asia)
UPDATE orders o
SET shipping_days = CASE 
    WHEN o.shipping_method = 'Overnight' THEN 4
    WHEN o.shipping_method = 'Express' THEN 7
    WHEN o.shipping_method = 'Standard' THEN 10
    ELSE 16 -- Economy
END
FROM locations l
WHERE o.location_id = l.location_id AND l.region = 'Asia';

SELECT 
    l.region,
    COUNT(o.order_id) AS total_orders
FROM orders o
JOIN locations l ON o.location_id = l.location_id
GROUP BY l.region
ORDER BY l.region;

-- Перевірка результатів оновлення стовпця shipping_days
SELECT 
    l.region,
    o.shipping_method,
    ROUND(AVG(o.shipping_days)::numeric, 1) AS avg_days_after
FROM orders o
JOIN locations l ON o.location_id = l.location_id
GROUP BY l.region, o.shipping_method
ORDER BY l.region, o.shipping_method;

-- Висновок: Після коригування терміни відображають реальну географічну відстань від США 
-- як країни розташування фулфілмент-центру бренду та диференціацію між методами доставки.

-- 2.2 Динаміка основних показників за роками

SELECT
    date_part('year', order_date) AS order_year,
    COUNT(order_id) AS total_orders,
    SUM(revenue) AS total_revenue,
    SUM(profit)AS total_profit,
    ROUND(AVG(profit_margin_pct), 2) AS avg_margin,
    COUNT(CASE WHEN is_unprofitable THEN 1 END) AS unprofitable_orders
FROM orders
GROUP BY date_part('year', order_date)
ORDER BY order_year;

-- Висновок: Динаміка продажів демонструє стабільне зростання з 2021 по 2023 рік:
-- кількість замовлень збільшилась у 4.9 рази (896 → 4375),виручка зросла у 4.6 рази (506к → 2.3 млн).
-- Це відповідає загальносвітовому тренду збільшення обсягів онлайн-торгівлі як основного каналу 
-- споживання, сформованому в період пандемії (2020-2021 роки).
-- У 2024 році зафіксовано різке падіння на 53% по кількості замовлень (4375 → 2042)
-- та на 50% по виручці (2.3 млн → 1.1 млн), що може свідчити про вплив глобальної невизначеності — 
-- тарифних бар'єрів, логістичних збоїв та макроекономічної нестабільності.
-- Середня маржинальність залишається стабільною протягом усього періоду (23-24%),
-- що свідчить про стійкість бізнес-моделі незважаючи на зовнішні фактори.
-- Частка збиткових замовлень стабільно складає ~13% щороку.

-- 2.3. Загальні показники по регіонах

SELECT
    region,
    SUM(total_orders) AS total_orders,
    SUM(total_revenue) AS total_revenue,
    SUM(total_profit) AS total_profit,
    ROUND(AVG(avg_margin), 2) AS avg_margin
FROM v_sales_by_country_year
GROUP BY region
ORDER BY total_revenue DESC;

-- Висновок: Усі чотири регіони демонструють порівнянні показники виручки та прибутку, що свідчить 
-- про рівномірну географічну диверсифікацію бренду. Лідером за виручкою та прибутком є Близький 
-- Схід ($1.35 млн / $384 тис.), маючи однакову кількість країн з Азією та Європою (по 5 країн).
-- Північна Америка з лише 3 країнами демонструє виручку $1.33 млн — найвищий показник виручки 
-- на країну серед усіх регіонів. Європа незначно відстає ($1.27 млн).
-- Найвища середня маржинальність — Близький Схід (24.39%), найнижча — Азія (23.13%), але різниця 
-- мінімальна. Рівномірний розподіл замовлень між регіонами підтверджує ефективність
-- стратегії єдиної вартості доставки як інструменту міжнародної експансії.

-- 2.4. Показники по країнах всередині регіонів

SELECT
    region,
    country,
    SUM(total_orders) AS total_orders,
    SUM(total_revenue) AS total_revenue,
    SUM(total_profit) AS total_profit,
    ROUND(AVG(avg_margin), 2) AS avg_margin
FROM v_sales_by_country_year
GROUP BY region, country
ORDER BY region, total_revenue DESC;

-- Висновок: Всередині регіонів розподіл виручки між країнами відносно рівномірний. 
-- В Азії лідирує Китай ($295 тис.), 
-- в Європі — Італія ($279 тис.),
-- на Близькому Сході — Єгипет ($344 тис, також найвищий показник серед усіх країн),
-- у Північній Америці — Канада ($454 тис).
-- Північна Америка має лише 3 країни проти 5 в інших регіонах, але демонструє найвищу виручку 
-- на країну (~$444 тис. в середньому).

-- 2.5. Розрахунок середнього чеку по регіонах

SELECT
    region,
    COUNT(DISTINCT country) AS total_countries,
    SUM(total_orders) AS total_orders,
    SUM(total_revenue) AS total_revenue,
    ROUND((SUM(total_revenue) / SUM(total_orders))::numeric, 2) AS avg_order_value
FROM v_sales_by_country_year
GROUP BY region
ORDER BY avg_order_value DESC;

-- Висновок: Лідером за середнім чеком є Близький Схід ($548.65), попри однакову кількість країн
-- з Азією та Європою. Північна Америка має найнижчий середній чек ($511.58), що може пояснюватись 
-- більшою часткою дрібних замовлень в регіоні базування бренду.
-- Різниця середніх чеків між регіонами незначна (~$37), що свідчить про збалансовану цінову
-- політику бренду на глобальному рівні.

-- 2.6. Аналіз ТОП-10 збиткових замовлень із використанням віконних функцій

SELECT
    country,
    category,
    discount,
    COUNT(order_id) AS total_orders,
    SUM(profit) AS total_profit,
    ROUND((COUNT(order_id)::numeric /
        SUM(COUNT(order_id)) OVER (PARTITION BY country) * 100), 2) AS pct_of_country
FROM v_unprofitable_orders
GROUP BY country, category, discount
ORDER BY total_profit ASC
LIMIT 10;

-- Висновок: ТОП-10 найзбитковіших комбінацій "країна-категорія продукту- знижка" підтверджують
-- раніше виявлену закономірність у Python: всі збитки генеруються виключно знижками 40-50% на Electronics
-- та Home & Kitchen як на категорії з найвищою вартістю товарів.
-- Примітно, що збитки концентруються на платоспроможних ринках зі стабільним курсом американського
-- долара (Канада, США, Іспанія, Південна Корея, Йорданія), тобто великі знижки застосовувались 
-- не через валютну кризу, а як інструмент утримання клієнтів.
-- Це підтверджує неефективність знижкової політики як інструменту утримання на платоспроможних 
-- ринках, оскільки бренд міг утримати клієнтів іншими методами (програми лояльності, сервіс, 
-- ексклюзивні пропозиції) без втрати прибутковості.

-- 2.7. Аналіз збитковості по країнах

SELECT
    l.country,
    l.region,
    COUNT(o.order_id) AS total_orders,
    SUM(o.revenue) AS total_revenue,
    SUM(o.profit) AS total_profit,
    COUNT(CASE WHEN o.is_unprofitable THEN 1 END) AS unprofitable_orders,
    ROUND((COUNT(CASE WHEN o.is_unprofitable THEN 1 END)::numeric / 
           COUNT(o.order_id) * 100), 2) AS unprofitable_pct
FROM orders o
JOIN locations l ON o.location_id = l.location_id
GROUP BY l.country, l.region
ORDER BY unprofitable_pct ASC;

-- Висновок: Жодна країна не є повністю беззбитковою — частка збиткових замовлень коливається від 10.10%
-- (Сінгапур, Азія) до 16.02% (Італія, Європа). Найнижчу частку збиткових замовлень демонструють:
-- Сінгапур (10.10%, Азія), Кувейт (11.55%, Близький схід), Південна Корея (11.73%, Азія) —
-- всі три є ринками з високою купівельною спроможністю та стабільною валютою. Найвищу частку збиткових
-- замовлень мають Італія (16.02%), Індія (15.49%), Японія (15.08%), що може свідчити про вищу чутливість
-- цих ринків до знижкової політики. Примітно що Єгипет (11.85%) попри валютну кризу має нижчий показник
-- збитковості ніж більшість європейських країн завдяки домінуванню дорогої категорії Electronics
-- з високою маржею. Середній показник збитковості по всіх країнах ~13% відповідає загальному показнику
-- датасету, виявленому на етапі очищення даних у Python.

-- 2.8. Зв'язок знижок та збитковості по країнах

SELECT
    l.country,
    l.region,
    COUNT(o.order_id) AS total_orders,
    ROUND(AVG(o.discount), 2) AS avg_discount,
    SUM(o.profit) AS total_profit,
    ROUND((COUNT(CASE WHEN o.is_unprofitable THEN 1 END)::numeric / 
           COUNT(o.order_id) * 100), 2) AS unprofitable_pct
FROM orders o
JOIN locations l ON o.location_id = l.location_id
GROUP BY l.country, l.region
ORDER BY avg_discount DESC;

-- Висновок: Аналіз підтверджує часткову кореляцію між середньою знижкою та часткою
-- збиткових замовлень: Італія та Іспанія мають найвищу середню знижку (0.19) і входять до топ-3
-- країн за часткою збиткових замовлень (16.02% та 14.93%). В той же час країни з середньою знижкою 0.17
-- (США, Франція, Кувейт, ОАЕ, Єгипет) демонструють нижчу частку збиткових замовлень (11-13%).
-- Однак кореляція не є абсолютною — деякі країни мають однакову знижку (0.18), але суттєво різну 
-- збитковість (10.10% vs 11.73%), що свідчить про вплив додаткових факторів — структури категорій,
-- купівельної спроможності та цінового сегменту товарів.
-- Таким чином, політика знижок є одним з ключових факторів збитковості, але не єдиним — стратегія
-- ціноутворення має враховувати специфіку кожного ринку окремо.

-- 2.9. Порівняння обсягів та знижок 2023 vs 2024 по країнах

SELECT
    l.country,
    l.region,
    COUNT(CASE WHEN date_part('year', o.order_date) = 2023 
        THEN 1 END) AS orders_2023,
    COUNT(CASE WHEN date_part('year', o.order_date) = 2024 
        THEN 1 END) AS orders_2024,
    ROUND(AVG(CASE WHEN date_part('year', o.order_date) = 2023 
        THEN o.discount END), 2) AS avg_discount_2023,
    ROUND(AVG(CASE WHEN date_part('year', o.order_date) = 2024 
        THEN o.discount END), 2) AS avg_discount_2024,
    ROUND((COUNT(CASE WHEN date_part('year', o.order_date) = 2024 
        THEN 1 END) -
           COUNT(CASE WHEN date_part('year', o.order_date) = 2023 
        THEN 1 END))::numeric /
        NULLIF(COUNT(CASE WHEN date_part('year', o.order_date) = 2023 
        THEN 1 END), 0) * 100, 2) AS orders_change_pct
FROM orders o
JOIN locations l ON o.location_id = l.location_id
GROUP BY l.country, l.region
ORDER BY orders_change_pct ASC;

-- Висновок: У 2024 році всі 18 країн показали падіння обсягів замовлень (від -43% до -62%).
-- Бренд реагував по-різному: одні ринки отримали підвищення знижок (Йорданія 0.16→0.20, Єгипет 0.17→0.20), 
-- інші — зниження (Кувейт 0.17→0.15), решта залишились без суттєвих змін.
-- Таким чином, підвищення знижок не зупинило падіння — Йорданія та Єгипет втратили -60% та -47% замовлень
-- відповідно, тоді як Сінгапур зі стабільною знижкою показав найменше падіння (-43%). Це свідчить про те,
-- що глобальне падіння попиту у 2024 році має системний характер і не може бути компенсоване знижковою
-- політикою.

-- 2.10. Аналіз політики знижок по Єгипту

SELECT
    l.country,
    o.discount,
    COUNT(o.order_id) AS total_orders,
    SUM(o.revenue) AS total_revenue,
    SUM(o.profit) AS total_profit,
    COUNT(CASE WHEN o.is_unprofitable THEN 1 END) AS unprofitable_orders
FROM orders o
JOIN locations l ON o.location_id = l.location_id
WHERE l.country = 'Egypt'
GROUP BY l.country, o.discount
ORDER BY o.discount;

-- Висновок: Аналіз політики знижок по Єгипту не підтвердив гіпотезу про застосування максимальних
-- знижок для підтримки обсягів продажів в умовах девальвації єгипетського фунта. Єгипетський фунт
-- знецінювався протягом усього досліджуваного періоду 2021-2024 років (~15.70 → ~47.50 EGP/USD, що
-- становить +180%), з найбільш різким обвалом у березні 2024 року.
-- Розподіл замовлень за рівнями знижок є рівномірним — найбільша частка припадає на замовлення 
-- без знижки (123 замовлення). Збиткові замовлення з'являються починаючи зі знижки 30% (8 замовлень)
-- і досягають максимуму при знижці 50% (28 замовлень із 33).
-- Висока виручка Єгипту ($344 тис.) пояснюється не знижковою політикою, а високою середньою вартістю
-- замовлення. Для підтвердження впливу девальвації на поведінку покупців доцільно дослідити динаміку
-- замовлень по Єгипту в розрізі категорій та років. 
-- Додатковий аналіз підтвердив парадоксальний ефект девальвації — короткострокове стимулювання попиту
-- на дорогі товари тривалого користування як інструменту захисту заощаджень. У 2024 році Єгипет став
-- лідером за виручкою попри найбільшу девальвацію національної валюти. 

-- 2.11. Динаміка замовлень по Єгипту в розрізі категорій та років

SELECT
    date_part('year', o.order_date) AS order_year,
    p.category,
    COUNT(o.order_id) AS total_orders,
    SUM(o.revenue) AS total_revenue,
    SUM(o.profit) AS total_profit,
    ROUND(AVG(o.discount), 2) AS avg_discount
FROM orders o
JOIN locations l ON o.location_id = l.location_id
JOIN products p ON o.product_id = p.product_id
WHERE l.country = 'Egypt'
GROUP BY date_part('year', o.order_date), p.category
ORDER BY order_year, total_revenue DESC;

-- 2.11.1. Середня знижка по Єгипту за роками

SELECT
    date_part('year', o.order_date) AS order_year,
    COUNT(o.order_id) AS total_orders,
    ROUND(AVG(o.discount), 2) AS avg_discount,
    SUM(o.revenue) AS total_revenue,
    COUNT(CASE WHEN o.is_unprofitable THEN 1 END) AS unprofitable_orders
FROM orders o
JOIN locations l ON o.location_id = l.location_id
WHERE l.country = 'Egypt'
GROUP BY date_part('year', o.order_date)
ORDER BY order_year;

-- Висновок: Динаміка замовлень по Єгипту підтверджує домінування категорії Electronics протягом 
-- усього досліджуваного періоду — її частка у виручці складає 70-80%. Зростання виручки з 
-- категорії Electronics протягом 2021-2023 років корелює з прискоренням девальвації єгипетського фунта — 
-- покупці прагнули придбати дорогу техніку до подальшого знецінення валюти. У 2024 році кількість 
-- замовлень в цілому по країні скоротилась майже вдвічі (-47%) на фоні різкого обвалу єгипетського фунта. 
-- Бренд відреагував підвищенням середньої знижки (0.17 → 0.20), проте це не зупинило падіння виручки
-- (-43%) та зростання частки збиткових замовлень (9% → 18%). 
-- Це підтверджує гіпотезу про вплив девальвації валюти на обсяги продажів, неефективність знижок як
-- інструменту утримання ринку в умовах девальвації та свідчить про необходимість адаптації стратегії 
-- для ринків з нестабільним курсом національної валюти.

-- 2.12. Втрачена вигода при застосуванні знижки понад 30%

-- Для розрахунку використано згенерований стовпець base_revenue — базова виручка
-- до застосування знижки (base_price × quantity). Розрахунок проведено для всіх
-- замовлень зі знижкою понад 30%, незалежно від того, є замовлення збитковим чи
-- прибутковим, оскільки знижка понад 30% розглядається як єдина допустима стеля
-- знижкової політики бренду.

SELECT
    COUNT(order_id) AS orders_with_high_discount,
    SUM(profit) AS actual_profit,
    SUM(base_revenue * 0.70 - costs) AS potential_profit_30pct,
    SUM(base_revenue * 0.70 - costs) - SUM(profit) AS lost_opportunity
FROM orders
WHERE discount > 0.30;

-- Висновок: Аналіз 1784 замовлень із знижкою понад 30% показав, що фактичний 
-- прибуток по них становить -$54,8 тис. (збиток), тоді як потенційний прибуток 
-- при обмеженні знижки до 30% склав би +$124,2 тис. Таким чином, втрачена вигода 
-- бренду через надмірну знижкову політику становить $179,1 тис. Це підтверджує 
-- висновок про необхідність встановлення максимальної знижки на рівні 30% як 
-- стандартної політики бренду, що дозволить збільшити прибуток без жодних 
-- додаткових інвестицій у маркетинг чи логістику,зважаючи на те, що розмір 
-- знижки не впливає ні на утримання клієнтів, ні на збільшення замовлень.

-- 2.13. Сезонність продажів

-- 2.13.1. Загальна динаміка обсягів продажів по місяцях

SELECT
    order_month,
    SUM(total_orders) AS total_orders,
    SUM(total_revenue) AS total_revenue
FROM v_monthly_dynamics
GROUP BY order_month
ORDER BY order_month;

-- 2.13.2. Обсяги продажів за сезонами

SELECT
    od.season,
    COUNT(o.order_id) AS total_orders,
    SUM(o.revenue) AS total_revenue,
    SUM(o.profit) AS total_profit,
    ROUND(AVG(o.profit_margin_pct)::numeric, 2) AS avg_margin
FROM orders o
JOIN order_dates od ON o.order_date = od.order_date
GROUP BY od.season
ORDER BY total_revenue DESC;

-- Висновок: Явної сезонності в датасеті не виявлено — кількість замовлень відносно рівномірна протягом
-- року. Проте можна виділити кілька спостережень: найнижчий показник — лютий (719 замовлень) — традиційне
-- затишшя після святкового сезону. Піки активності — серпень (906 замовлень) та жовтень ($501 тис.
-- виручки) можуть бути пов'язані з розпродажами та підготовкою до зимового сезону. Найбільша виручка 
-- спостерігається навесні, найвища маржинальність - восени. Відсутність різкої сезонності є перевагою 
-- для D2C-бренду — рівномірне завантаження логістики та складських потужностей протягом року знижує 
-- операційні витрати. 

-- 2.14. Основні показники продажів у розрізі категорій.

SELECT
    category,
    sub_category,
    total_orders,
    total_revenue,
    total_profit,
    avg_discount
FROM v_sales_by_category
ORDER BY total_revenue DESC;

-- Висновок: Беззаперечний лідер за виручкою — Electronics ($3.38 млн, 47% загальної виручки),
-- зокрема Laptops ($1.64 млн) та Smartphones ($0.84 млн).Найбільша кількість замовлень — Beauty & Health
-- (Skincare 1044 од., Supplements 951од.) та Books & Media (Books 1022 од., Software 1021од.), але з 
-- низькою виручкою, що свідчить про низький середній чек цих категорій.
-- Таким чином, варто выдзначити пріоритет у просуванні категорії Electronics, особливо Laptops та 
-- Smartphones.

-- 2.15. Тенденції по категоріях за роками

SELECT
    p.category,
    date_part('year', o.order_date) AS order_year,
    COUNT(o.order_id) AS total_orders,
    SUM(o.revenue) AS total_revenue,
    SUM(o.profit) AS total_profit,
    ROUND(AVG(o.profit_margin_pct), 2) AS avg_margin
FROM orders o
JOIN products p ON o.product_id = p.product_id
GROUP BY p.category, date_part('year', o.order_date)
ORDER BY order_year, total_revenue DESC;

-- Висновок: категорія Electronics домінує у виручці протягом усього періоду (64-70% щороку).
-- Зростання протягом 2021-2023 років рівномірне по всіх категоріях. У 2024 році падіння відбувається
-- також рівномірно, що підтверджує його системний характер. У 2024 році при загальному падінні 
-- продажів на 53% частка Electronics у виручці зросла, що свідчить про її пріоритетність для 
-- покупців навіть в умовах економічної нестабільності та підтверджує стратегічну важливість 
-- категорії для бренду.
-- Маржинальність Clothing у 2024 зросла до 26.25% за рахунок зниження відсотка знижки за цією 
-- категорією. В цілому можна відзначити, що Electronics залишається пріоритетною категорією, 
-- Clothing демонструє потенціал підвищення маржинальності при оптимізації знижкової політики.

-- 2.16. ТOП-категорії по регіонах

SELECT
    l.region,
    p.category,
    COUNT(o.order_id) AS total_orders,
    SUM(o.revenue) AS total_revenue,
    SUM(o.profit) AS total_profit,
    ROUND(AVG(o.profit_margin_pct), 2) AS avg_margin,
    ROUND((SUM(o.revenue) / 
        SUM(SUM(o.revenue)) OVER (PARTITION BY l.region) * 100), 2) AS pct_of_region
FROM orders o
JOIN locations l ON o.location_id = l.location_id
JOIN products p ON o.product_id = p.product_id
GROUP BY l.region, p.category
ORDER BY l.region, total_revenue DESC;

-- Висновок: Структура категорій є однаковою у всіх чотирьох регіонах — Electronics домінує (62-65% 
-- виручки), Home & Kitchen на другому місці (15-17%), інші категорії ділять решту порівну (7-8% кожна).
-- Відсутність регіональної диференціації у структурі категорій свідчить про універсальність попиту 
-- на асортимент бренду та є характерною особливістю синтетичного датасету.
-- Для реального бізнесу це означало б відсутність необхідності локальної адаптації асортименту. Однак 
-- на практиці регіональні відмінності у попиті є нормою і потребують окремого дослідження.

-- 2.17. ТОП-5 товарів

-- 2.17.1. По кількості проданих одиниць
SELECT
    p.product_name,
    p.category,
    p.sub_category,
    SUM(o.quantity) AS total_units_sold,
    SUM(o.revenue) AS total_revenue,
    SUM(o.profit) AS total_profit,
    ROUND(AVG(o.profit_margin_pct), 2) AS avg_margin
FROM orders o
JOIN products p ON o.product_id = p.product_id
GROUP BY p.product_name, p.category, p.sub_category
ORDER BY total_units_sold DESC
LIMIT 5;

-- 2.17.2. По виручці
SELECT
    p.product_name,
    p.category,
    p.sub_category,
    SUM(o.quantity) AS total_units_sold,
    SUM(o.revenue) AS total_revenue,
    SUM(o.profit) AS total_profit,
    ROUND(AVG(o.profit_margin_pct), 2) AS avg_margin
FROM orders o
JOIN products p ON o.product_id = p.product_id
GROUP BY p.product_name, p.category, p.sub_category
ORDER BY total_revenue DESC
LIMIT 5;

-- Висновок: Аналіз топ-товарів підтверджує ключову закономірність датасету: кількість проданих одиниць
-- не дорівнює виручка. Топ за одиницями — дешеві товари Beauty & Health та Books & Media
-- (Vitamin C Serum 662 од., $26 тис. виручки). Топ за виручкою — виключно ноутбуки категорії Electronics
-- (Lenovo ThinkPad X1 лідер з $379 тис. при лише 308 одиницях). Таким чином, для максимізації виручки 
-- пріоритет повинен надаватися просуванню преміум-техніки.

-- 2.18. ТOП-10 клієнтів

-- 2.18.1. По кількості замовлень
SELECT
    o.customer_id,
    c.customer_segment,
    c.customer_gender,
    l.country,
    l.region,
    COUNT(o.order_id) AS total_orders,
    SUM(o.revenue) AS total_revenue,
    SUM(o.profit) AS total_profit
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN locations l ON o.location_id = l.location_id
GROUP BY o.customer_id, c.customer_segment, c.customer_gender, l.country, l.region
ORDER BY total_orders DESC
LIMIT 10;

-- 2.18.2. По виручці
SELECT
    o.customer_id,
    c.customer_segment,
    c.customer_gender,
    l.country,
    l.region,
    COUNT(o.order_id) AS total_orders,
    SUM(o.revenue) AS total_revenue,
    SUM(o.profit) AS total_profit
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN locations l ON o.location_id = l.location_id
GROUP BY o.customer_id, c.customer_segment, c.customer_gender, l.country, l.region
ORDER BY total_revenue DESC
LIMIT 10;

-- Висновок: Топ-10 клієнтів за кількістю замовлень (max 4) та за виручкою демонструють відсутність 
-- кореляції між кількістю замовлень та виручкою, що характерно для синтетичного датасету.
-- У реальному D2C-бізнесі найвищу виручку генерують лояльні клієнти з багаторазовими покупками, 
-- тоді як тут топ за виручкою складається виключно з одноразових замовлень на преміум-техніку.
-- 8 з 10 топ-клієнтів за виручкою — жінки. США відсутні в топі попри статус домашнього ринку бренду,
-- в той час як Єгипет представлений двічі попри валютну кризу.

-- 2.19. Retention/Churn аналіз

-- 2.19.1. За актуальним статусом з таблиці-довідника customers (статус клієнта на дату останнього
-- замовлення)
SELECT
    c.customer_segment,
    COUNT(DISTINCT o.customer_id) AS total_customers,
    COUNT(DISTINCT CASE WHEN order_count = 1 
        THEN o.customer_id END) AS one_time_customers,
    COUNT(DISTINCT CASE WHEN order_count > 1 
        THEN o.customer_id END) AS returning_customers,
    ROUND((COUNT(DISTINCT CASE WHEN order_count > 1 
        THEN o.customer_id END)::numeric /
        COUNT(DISTINCT o.customer_id) * 100), 2) AS retention_pct,
    ROUND((COUNT(DISTINCT CASE WHEN order_count = 1 
        THEN o.customer_id END)::numeric /
        COUNT(DISTINCT o.customer_id) * 100), 2) AS churn_pct
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN (
    SELECT customer_id, COUNT(order_id) AS order_count
    FROM orders
    GROUP BY customer_id
) order_counts ON o.customer_id = order_counts.customer_id
GROUP BY c.customer_segment
ORDER BY retention_pct DESC;

-- 2.19.2. За історичним статусом з вихідної таблиці ecommerce_sales (статус клієнта на момент кожного 
-- конкретного замовлення)
SELECT
    e."Customer_Segment" AS historical_segment,
    COUNT(DISTINCT o.customer_id) AS total_customers,
    COUNT(DISTINCT CASE WHEN order_count = 1 
        THEN o.customer_id END) AS one_time_customers,
    COUNT(DISTINCT CASE WHEN order_count > 1 
        THEN o.customer_id END) AS returning_customers,
    ROUND((COUNT(DISTINCT CASE WHEN order_count > 1 
        THEN o.customer_id END)::numeric /
        COUNT(DISTINCT o.customer_id) * 100), 2) AS retention_pct,
    ROUND((COUNT(DISTINCT CASE WHEN order_count = 1 
        THEN o.customer_id END)::numeric /
        COUNT(DISTINCT o.customer_id) * 100), 2) AS churn_pct
FROM orders o
JOIN ecommerce_sales e ON o.order_id = e."Order_ID"
JOIN (
    SELECT customer_id, COUNT(order_id) AS order_count
    FROM orders
    GROUP BY customer_id
) order_counts ON o.customer_id = order_counts.customer_id
GROUP BY e."Customer_Segment"
ORDER BY retention_pct DESC;

-- Висновок: Порівняння двох підходів до аналітики сегментів клієнтів демонструє суттєву різницю 
-- в результатах. Підхід за актуальними даними показує retention 54-57% з мінімальною різницею
-- між сегментами (~2%), що може бути характерно для сентетичного датасету, але не відповідає 
-- реальній бізнес-логіці програм лояльності.
-- Підхід за історичними даними дає коректніші результати: VIP — найвищий retention (74.64%), Regular —
-- найнижчий (66.00%), різниця між сегментами ~8% відповідає очікуваній поведінці лояльних клієнтів.
-- Найвищий churn у сегменті Regular (34%) визначає пріоритетну групу для програм утримання клієнтів.

-- 2.20. Перевірка географічної мобільності клієнтів

SELECT
    o.customer_id,
    COUNT(DISTINCT l.country) AS unique_countries,
    STRING_AGG(DISTINCT l.country, ', ') AS countries
FROM orders o
JOIN locations l ON o.location_id = l.location_id
GROUP BY o.customer_id
HAVING COUNT(DISTINCT l.country) > 1
ORDER BY unique_countries DESC 
LIMIT 10;

-- Висновок: Окремі клієнти робили замовлення з 6-7 різних країн протягом 2021-2024, що унеможливлює 
-- прив'язку локації до клієнта в таблиці customers і підтверджує коректність архітектурного рішення 
-- зберігати location_id в таблиці orders як атрибут транзакції.

-- 2.21. Перевірка розподілу клієнтів за кількістю замовлень

WITH customer_orders AS (
    SELECT customer_id, COUNT(order_id) AS order_count
    FROM orders
    GROUP BY customer_id
)
SELECT
    COUNT(*) AS customers_with_this_count,
    order_count AS total_orders_per_customer
FROM customer_orders
GROUP BY order_count
ORDER BY order_count;

-- Висновок: Найбільша кількість клієнтів (2419 чол.) зробила по 1 замовленню, що становить 45,2% від 
-- загальної кількості клієнтів бренду. Найбільшу кількість замовлень (9 од.) зробив лише 1 клієнт. 
-- Розподіл клієнтів у групах по 6-7 замовлень на одного клієнта підтверджує результати перевірки 
-- географічної мобільності клієнтів.

-- 2.22. Аналіз знижок по історичному сегменту клієнтів

SELECT
    e."Customer_Segment" AS historical_segment,
    o.discount,
    COUNT(o.order_id) AS total_orders,
    SUM(o.profit) AS total_profit,
    COUNT(CASE WHEN o.is_unprofitable THEN 1 END) AS unprofitable_orders,
    ROUND((COUNT(CASE WHEN o.is_unprofitable THEN 1 END)::numeric /
        COUNT(o.order_id) * 100), 2) AS unprofitable_pct
FROM orders o
JOIN ecommerce_sales e ON o.order_id = e."Order_ID"
WHERE o.discount IN (0.40, 0.50)
GROUP BY e."Customer_Segment", o.discount
ORDER BY e."Customer_Segment", o.discount;

-- Висновок: Аналіз збиткових знижок (40% та 50%) по сегментах виявив таку закономірність:
-- знижки розподілені між усіма сегментами відносно рівномірно. Знижка 50% є катастрофічною
-- для всіх сегментів: збитковість складає 82-87%, Regular сегмент мав найбільший збиток 
-- (-$31 тис.), що підтверджує намагання бренду утримати цей сегмент за рахунок великих знижок.
-- Знижка 40%  для сегменту Regular залишається прибутковою ($2.2 тис.), тоді як всі інші 
-- сегменти у збитку. Найбільші абсолютні збитки спостерігаються за сегментом Regular 
-- як за найчисельнішим сегментом. Найвища відносна збитковість при 50% спостерігається за
-- сегментом VIP (87.37%).
-- Таким чином, підтверджується попередній висновок, що знижка 50% є економічно невиправданою
-- для будь-якого сегменту клієнтів, не впливає на збільшення обсягів продажів і має бути 
-- виключена з цінової політики бренду. Знижка 40% може застосовуватись обережно лише для 
-- Regular сегменту при умові контролю прибутковості категорій товарів.

-- 2.23. Аналіз вартості доставки

-- 2.23.1. Динаміка по роках

SELECT
    order_year,
    shipping_method,
    total_orders,
    avg_shipping_cost,
    total_shipping_cost,
    total_orders - LAG(total_orders) OVER (
        PARTITION BY shipping_method ORDER BY order_year) AS orders_change,
    ROUND((avg_shipping_cost - LAG(avg_shipping_cost) OVER (
        PARTITION BY shipping_method ORDER BY order_year)), 2) AS cost_change
FROM (
    SELECT
        date_part('year', o.order_date) AS order_year,
        o.shipping_method,
        COUNT(o.order_id) AS total_orders,
        ROUND(AVG(o.shipping_cost), 2) AS avg_shipping_cost,
        SUM(o.shipping_cost) AS total_shipping_cost
    FROM orders o
    GROUP BY date_part('year', o.order_date), o.shipping_method
) 
ORDER BY order_year, total_orders DESC;

-- 2.23.2. По методах та регіонах

SELECT
    l.region,
    o.shipping_method,
    COUNT(o.order_id) AS total_orders,
    ROUND(AVG(o.shipping_cost), 2) AS avg_shipping_cost,
    SUM(o.shipping_cost) AS total_shipping_cost,
    ROUND((COUNT(o.order_id)::numeric /
        SUM(COUNT(o.order_id)) OVER (PARTITION BY l.region) * 100), 2) AS pct_of_region
FROM orders o
JOIN locations l ON o.location_id = l.location_id
GROUP BY l.region, o.shipping_method
ORDER BY l.region, total_orders DESC;

-- Висновок: Вартість доставки стабільна протягом 2021-2024 років (зміни не перевищують $0.60)
-- та однакова у всіх регіонах незалежно від географічної відстані. У 2024 році падіння замовлень
-- рівномірне по всіх методах доставки (-563 до -608), що підтверджує системний характер падіння 
-- попиту.
-- Розподіл методів доставки по регіонах є рівномірним (у середньому ~25% кожен метод),
-- клієнти у всіх регіонах однаково обирають Economy, Standard, Express та Overnight, що характерно для
-- синтетичного датасету.
-- Бренд не використовував ні вартість, ні метод доставки як інструмент впливу на попит ні в період
-- зростання, ні в період падіння. Таким чином, диференціація вартості доставки по регіонах
-- може стати додатковим інструментом стимулювання попиту на пріоритетних ринках.

-- 2.24. Аналіз статусів замовлень по регіонах

SELECT
    l.region,
    o.order_status,
    COUNT(o.order_id) AS total_orders,
    ROUND((COUNT(o.order_id)::numeric /
        SUM(COUNT(o.order_id)) OVER (PARTITION BY l.region) * 100), 2) AS pct_of_region
FROM orders o
JOIN locations l ON o.location_id = l.location_id
GROUP BY l.region, o.order_status
ORDER BY l.region, total_orders DESC;

-- Висновок: Структура статусів замовлень є однаковою у всіх регіонах: Delivered ~63%, 
-- Returned ~18-19%, Processing ~9-10%, Cancelled ~8-9%. Рівень повернень (18-19%) є критично 
-- високим для D2C-бізнесу, тобто кожне п'яте замовлення повертається.
-- Найвищий рівень повернень — Європа та Близький Схід (19.09% та 19.08%), найнижчий — Північна Америка
-- (17.95%) як домашній ринок бренду. Рівень скасувань стабільний в межах 8-10%, що свідчить про 
-- системні проблеми з конверсією замовлень у доставку.
-- В датасеті статуси "Returned" та "Cancelled" є суто інформаційними мітками і не впливають на 
-- фінансові показники (Revenue, Profit, Cost).
-- У реальному бізнесі Returned зменшують виручку та збільшують операційні витрати, на зворотню 
-- логістику та обробку повернень. Cancelled є втраченим доходом та свідчать про проблеми
-- з конверсією замовлень у доставку. Фактичний рівень прибутковості бренду може бути суттєво нижчим
-- з урахуванням ~18-19% повернень та ~8-9% скасувань по всіх регіонах, реальна ефективна виручка 
-- складати не більше ~73% від задекларованої.
-- Таким чином, зниження рівня повернень та скасувань за рахунок оптимізації операційної діяльності 
-- збільшило б ефективну виручку бренду. 

-- 2.25. Методи оплати по регіонах

SELECT
    l.region,
    o.payment_method,
    COUNT(o.order_id) AS total_orders,
    ROUND((COUNT(o.order_id)::numeric /
        SUM(COUNT(o.order_id)) OVER (PARTITION BY l.region) * 100), 2) AS pct_of_region
FROM orders o
JOIN locations l ON o.location_id = l.location_id
GROUP BY l.region, o.payment_method
ORDER BY l.region, total_orders DESC;

-- Висновок: Розподіл методів оплати є рівномірним у всіх регіонах (~13-15% кожен метод), що
-- характерно для синтетичного датасету. У реальному бізнесі регіональні відмінності були б суттєвими:
-- Азія — домінування мобільних платежів (Google Pay, Apple Pay),
-- Близький Схід — висока частка готівки (Cash on Delivery),
-- Північна Америка — кредитні картки та PayPal,
-- Європа — банківські перекази через регуляторні вимоги.
-- Відсутність регіональної диференціації методів оплати є обмеженням датасету для аналізу платіжної
-- поведінки споживачів. В умовах реального бізнесу адаптація платіжних методів під регіональні 
-- особливості є одним з ключових факторів конверсії.

-- ========================
-- РОЗДІЛ 3. AB-ТЕСТУВАННЯ
-- ========================

-- 3.1. AB-тест: вплив стабільності валюти на обсяги продажів

-- Група A: країни з фіксованим курсом (pegged currencies)
-- Група B: країни з плаваючим курсом

SELECT
    CASE 
        WHEN l.country IN ('UAE', 'Saudi Arabia', 'Jordan', 'Kuwait', 'USA')
		THEN 'A: Стабільний курс'
        ELSE 'B: Плаваючий курс'
    END AS test_group,
    COUNT(DISTINCT l.country) AS total_countries,
    COUNT(o.order_id) AS total_orders,
    ROUND(AVG(o.revenue), 2) AS avg_order_revenue,
    ROUND(AVG(o.profit), 2) AS avg_order_profit,
    ROUND(AVG(o.profit_margin_pct), 2) AS avg_margin,
    ROUND(AVG(o.discount), 2) AS avg_discount,
    COUNT(CASE WHEN o.is_unprofitable THEN 1 END) AS unprofitable_orders,
    ROUND((COUNT(CASE WHEN o.is_unprofitable THEN 1 END)::numeric /
        COUNT(o.order_id) * 100), 2) AS unprofitable_pct
FROM orders o
JOIN locations l ON o.location_id = l.location_id
GROUP BY test_group
ORDER BY test_group;

-- Висновок: До групи A зі стабільним курсом увійшло 5 країн, в тому числі USA як країна розташування
-- бренду (всі фінансові показники датасету прив'язані до американського долару), до група B  з 
-- плаваючим курсом увійшло 13 країн. Середній чек замовлення вищий у групі B ($533 vs $516), проте 
-- середній прибуток практично однаковий ($143.89 vs $143.71). Маржинальність вища у групі A (24.23% 
-- vs 23.42%) тобто країни зі стабільним курсом генерують прибуток ефективніше. Збитковість відповідно 
-- нижча у групі A (12.76% vs 13.62%) - стабільний курс валюти корелює з нижчим рівнем збиткових 
-- замовлень. Середня знижка у групі A нижча (0.17 vs 0.18), отже бренд менше стимулює попит знижками
-- на стабільних ринках.
-- Таким чином, ринки зі стабільним курсом валюти демонструють вищу маржинальність та нижчу збитковість
-- та є пріоритетними ринками для подальшої експансії з точки зору фінансової ефективності.

-- 3.2. AB тест: вплив вартості доставки на обсяги продажів

-- Група A: країни з низькою вартістю доставки (нижче середньої)
-- Група B: країни з високою вартістю доставки (вище середньої)

-- використано CTE для попереднього розрахунку середньої вартості доставки по всьому датасету
-- та для кожної країни з метою подальшого порівняння 

WITH avg_shipping AS (
    SELECT AVG(o.shipping_cost) AS avg_cost
    FROM orders o
),
country_shipping AS (
    SELECT
        l.country,
        AVG(o.shipping_cost) AS country_avg_cost
    FROM orders o
    JOIN locations l ON o.location_id = l.location_id
    GROUP BY l.country
)
SELECT
    CASE
        WHEN cs.country_avg_cost < avg_shipping.avg_cost
            THEN 'A: Дешева доставка'
        ELSE 'B: Дорога доставка'
    END AS test_group,
    COUNT(DISTINCT l.country) AS total_countries,
    COUNT(o.order_id) AS total_orders,
    ROUND(AVG(o.shipping_cost), 2) AS avg_shipping_cost,
    ROUND(AVG(o.revenue), 2) AS avg_order_revenue,
    ROUND(AVG(o.profit), 2) AS avg_order_profit,
    ROUND(AVG(o.profit_margin_pct), 2) AS avg_margin,
    COUNT(CASE WHEN o.is_unprofitable THEN 1 END) AS unprofitable_orders,
    ROUND((COUNT(CASE WHEN o.is_unprofitable THEN 1 END)::numeric /
        COUNT(o.order_id) * 100), 2) AS unprofitable_pct
FROM orders o
JOIN locations l ON o.location_id = l.location_id
JOIN country_shipping cs ON l.country = cs.country
CROSS JOIN avg_shipping
GROUP BY test_group
ORDER BY test_group;

-- Висновок: До групи A (дешева доставка) увійшло 7 країн із середньою вартістю доставки $31.21,
-- до групи B (дорога доставка) — 11 країн із середньою вартістю $32.98. Різниця у вартості доставки 
-- між групами становить лише $1.77, що є характерною особливістю синтетичного датасету з єдиною 
-- ціновою політикою доставки.
-- Група B (дорога доставка) демонструє вищий середній чек ($537 vs $513), вищий прибуток ($148 vs 
-- $136) та вищу маржинальність (23.81% vs 23.38%), що може вказувати на покупку дорогих товарів та 
-- їх доставку більш надійним, але й дорожчим способом. Збитковість практично однакова в обох групах
-- і становить відповідно 13.64% і 13.22%.
-- Таким чином, за даними датасету вартість доставки не має суттєвого впливу на обсяги продажів та 
-- прибутковість — різниця між групами незначна і може пояснюватись структурою категорій товарів у 
-- кожній групі країн, а не вартістю доставки.
-- В умовах реального бізнесу вплив вартості доставки був би значно суттєвішим, зокрема зростання 
-- вартості доставки безпосередньо знижує конверсію замовлень, що підтверджується практичним досвідом
-- продавців на міжнародних маркетплейсах. Даний фактор є ключовим для сценарного моделювання 
-- стратегії експансії в умовах глобальної невизначеності.







